# Import
#
# use /import to import xml data passed by http
# use /import_url to import xml data from a url

## option to async import: need to poll

### add user, group id params
get "/import/scenario/:filename" do |filename|
  protected!
#  params[:access_token] or not_authorized!

  log.info "Attempting to import #{params[:bucket]}/#{filename}"

  import_options = {}

  if params[:from_user]
    import_options[:redmine_user_id] = params[:from_user]
  end

  if can_access?({:type => 'Project',
    :id => params[:to_project]}, params[:access_token])
    stream_cautiously do |out|
      xml_plaintext = s3.fetch(filename, params[:bucket])
      log.info "loaded XML data from #{filename} for import"
      xml_data = Nokogiri.XML(xml_plaintext).xpath("/scenario")[0]
      Aurora::ImportUtil.rekey!(xml_data)
      scenario = import_scenario_xml(xml_data, params[:to_project], import_options)
      log.info "scenario imported to project #{scenario.project_id}: #{scenario.id}" if scenario 
  
      if params[:jsoncallback]
        script = jsonp({:success => scenario.id})
        log.debug "returning #{script} as JSONP"
        out << script
      else
        # For debugging, that callback is an annoying parameter to require
        content_type :json
        out << {:success => scenario.id}.to_json
      end
    end
  else
    not_authorized!
  end
end

get "/duplicate/:type/:id" do |type, id|
  received_type = type_translator[type]
  numeric_id = id.to_i
  overrides = {}
  project_dest = params[:to_project]
  overrides[:project_id] = project_dest if project_dest

  if !received_type
    log.error "bad type #{type} for duplicate of #{type}:#{id}"
    raise "bad type for duplicate"
  end

  if can_access?({ :type => received_type.to_s.split('::').last, 
                   :id => numeric_id },
                 params[:access_token])
    stream_cautiously do |out|
      object = received_type[numeric_id]
      if object 
        if params[:deep] && object.respond_to?(:deep_copy)
          copy = object.deep_copy(DB, overrides)
        else
          copy = object.shallow_copy(DB, overrides)
        end
 
        if params[:jsoncallback]
          script = jsonp({:success => copy.id})
          log.debug "returning #{script} as JSONP"
          out << script
        else
          # For debugging, that callback is an annoying parameter to require
          content_type :json
          out << {:success => copy.id}.to_json
        end
      else
        out << {:failure => "#{type} not found"}.to_json
      end
    end
  else
    not_authorized!
  end
end

# /import
# body is the xml data
# returns [table, id].to_yaml, where table is name of table of top-level
# object of the xml (e.g. scenario) and id is its id in the db.
post "/import" do
  protected!

  stream_cautiously do |out|
    table, id = get_upload do |f|
      import_xml(f)
    end
    log.info "finished importing: #{table} ##{id}"
    out << [table, id].to_yaml
  end
end

# /import_url
# body is the url
# returns [table, id].to_yaml, where table is name of table of top-level
# object of the xml (e.g. scenario) and id is its id in the db.
post "/import_url" do
  protected!

  stream_cautiously do |out|
    xml_url = request.body.read
    log.info "importing url: #{xml_url.inspect}"
    xml_data = open(xml_url) {|f| f.read} ###
    log.info "read #{xml_data.size} bytes of xml data"
    table, id = import_xml(xml_data)
    log.info "finished importing: #{xml_url.inspect}"
    out << [table, id].to_yaml
  end
end


# Export

# Exports the scenario and returns the xml string in the response body, with
# content type application/xml.

get "/model/scenario-by-key/:key.xml" do |key|
  protected!
# This route is accessed by key, not id, so no need to check this:
#  access_token = params[:access_token]
#  access_token or not_authorized!

  entry = lookup_apiweb_key(key)
  if !entry
    msg = "No scenario for key=#{key}"
    log.warn msg
    break msg
  end

  log.info "requested scenario #{entry[:model_id]} as xml"
  stream_cautiously do |out|
    content_type :xml
    out << export_scenario_xml(entry[:model_id])
  end
end

get "/model/scenario/:id.xml" do |id|
  protected!

  log.info "requested scenario #{id} as xml"

  if can_access?({:type => 'Scenario', 
                  :id => id}, params[:access_token])
    attachment("scenario-#{id}.xml")
    stream_cautiously do |out|
      content_type :xml
      out << export_scenario_xml(id)
    end
  else
    not_authorized!
  end
end

# Exports the scenario, uploads the xml string to webtmp, and returns the url
# in the response body, with content type text/plain.

get "/model/scenario/:id.url" do |id|
  protected!
  log.info "requested scenario #{id} as url"
  
  stream_cautiously do |out|
    content_type :text
    xml = export_scenario_xml(id)
    params["ext"] = "xml"
    url = webtmp.store(xml, params)
    out << url
  end
end

get "/model/network/:id.xml" do |id|
  protected!
  
  log.info "requested wrapped network #{id} as xml"
  
  if can_access?({:type => 'Network', 
                  :id => id}, params[:access_token])
    attachment("network-#{id}.xml")
    stream_cautiously do |out|
      content_type :xml

      xml = export_network_xml(id)
      if xml
        out << xml
      else
        out << "dbweb error -- see logs"
      end
    end
  else
    not_authorized!
  end
end


get "/model/wrapped-network-by-key/:key.xml" do |key|
  protected!
# This route is accessed by key, not id, so no need to check this:
#  access_token = params[:access_token]
#  access_token or not_authorized!
  
  entry = lookup_apiweb_key(key)
  if !entry
    msg = "No network for key=#{key}"
    log.warn msg
    break msg
  end

  log.info "requested wrapped network #{entry[:model_id]} as xml"
  
  stream_cautiously do |out|
    content_type :xml

    xml = export_wrapped_network_xml(entry[:model_id])
    if xml
      out << xml
    else
      out << "dbweb error -- see logs"
    end
  end
end

# Exports the scenario, uploads the xml string to webtmp, and returns a html
# response that, when loaded in the client browser, runs our flash app, which
# then loads the url passed to it by fashvars.

get "/editor/scenario/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested scenario #{id} in editor"
  
  if can_access?({:type => 'Scenario', 
                  :id => id}, params[:access_token])
    stream_cautiously do |out|
      content_type :html

      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "scenario",
        :model_id => id,
        :access_token => access_token
      )
      
      @export_url = "/model/scenario-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]
      
      @dbweb_key = key

      KEY_TO_ID[key] = [id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/editor/network/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested network #{id} in editor"
  
  if can_access?({:type => 'Network', 
                  :id => id}, access_token)
    stream_cautiously do |out|
      content_type :html

      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]

      @dbweb_key = key

      KEY_TO_ID[key] = [id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/editor/controller_set/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested controller set #{id} in editor"
  
  if can_access?({:type => 'ControllerSet', 
                  :id => id}, access_token)
    stream_cautiously do |out|
      content_type :html
      cs = Aurora::ControllerSet[Integer(id)]
      network_id = cs.network_id

      @focus = 'controller_set'
      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => network_id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/editor/demand_profile_set/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested demand profile set #{id} in editor"
  
  if can_access?({:type => 'DemandProfileSet', 
                  :id => id}, access_token)
    stream_cautiously do |out|
      content_type :html
      dps = Aurora::DemandProfileSet[Integer(id)]
      network_id = dps.network_id

      @focus = 'demand-profile-set'
      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => network_id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/editor/split_ratio_profile_set/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested split ratio profile set #{id} in editor"
  
  if can_access?({:type => 'SplitRatioProfileSet', 
                  :id => id}, access_token)
    stream_cautiously do |out|
      content_type :html
      srps = Aurora::SplitRatioProfileSet[Integer(id)]
      network_id = srps.network_id

      @focus = 'split-ratio-profile-set'
      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => network_id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/editor/capacity_profile_set/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested capacity profile set #{id} in editor"
  
  if can_access?({:type => 'CapacityProfileSet', 
                  :id => id}, access_token)
    stream_cautiously do |out|
      content_type :html
      cps = Aurora::CapacityProfileSet[Integer(id)]
      network_id = cps.network_id

      @focus = 'capacity-profile-set'
      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => network_id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/editor/event_set/:id.html" do |id|
  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  log.info "requested event set #{id} in editor"
  
  if can_access?({:type => 'EventSet', 
                  :id => id}, access_token)
    stream_cautiously do |out|
      content_type :html
      es = Aurora::EventSet[Integer(id)]
      network_id = es.network_id

      @focus = 'event-set'
      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => network_id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"

      @simx_group = ENV["SIMX_GROUP"]
      @simx_user  = ENV["SIMX_USER"]

      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]

      out << haml(:flash_edit)
    end
  else
    not_authorized!
  end
end

get "/reports/:report_id/report_xml" do |report_id|
  access_token = params[:access_token]
  log.debug "report_id = #{report_id}"

  if can_access?({:type => 'SimulationBatchReport', 
                  :id => report_id}, access_token)
    stream_cautiously do |out|
      @report = Aurora::SimulationBatchReport[report_id]
      if params[:jsoncallback]
        script = jsonp({:xml => @report.s3_xml})
        out << script
      else
        # For debugging, that callback is an annoying parameter to require
        content_type :xml
        out << @report.s3_xml
      end
    end
  else
    not_authorized!
  end
end

get "/file/:filename" do |filename|
  protected!

  stream_cautiously do |out|
    log.info "deferred fetch of #{filename}"
    out << s3.fetch(filename)
  end
end

get "/tmp/:filename" do |filename|
  protected!

  stream_cautiously do |out|
    attachment(filename)
    log.info "deferred fetch of #{filename}"
    out << webtmp.fetch(filename)
  end
end

post "/store" do
  log.warn "deprecated route: /store; use /file or /tmp instead; assuming /file"
  redirect "/file"
end

# For long-term storage that will not be delete until a user request, or a
# user-given expiration. This is good for user-created content.
#
# Storage may be s3 or local, depending on the aws mock flag.
#
# +params+ can include "expiry", "ext".
#
# Data is in the "file" field. For example:
#
#  curl localhost:4567/file -F file=@some_file
#
# Returns the url, which is based on the md5 hash of the data, plus the
# specified file extension, if any, which s3 uses to make a content-type header.
# Expiry is in seconds. Default is none. Expiry is not guaranteed, but will not
# happen before the specified number of seconds has elapsed.
#
post "/file" do
  protected!
  
  host_with_port = request.host_with_port
  
  stream_cautiously do |out|
    log.info "started deferred file store operation"
    log.debug "params = #{params.inspect}"
    
    url =
      get_upload do |f|
        s3.store(f, params)
      end

    if url !~ /^\w+:/
      # in case of local storage, url omits the proto, host, port
      url = "http://#{host_with_port}#{url}"
    end

    log.info "finished deferred store operation, url = #{url}"
    out << url
  end
end

# For short-term storage that can be deleted at any time, but will (almost)
# always exist for long enough to download it. This is good for db exports,
# sim results, etc.
#
# +params+ can include "expiry", "ext".
#
# Data is in the "file" field. For example:
#
#  curl localhost:4567/tmp -F file=@some_file
#
post "/tmp" do
  protected!

  host_with_port = request.host_with_port
  
  stream_cautiously do |out|
    log.info "started deferred tmp store operation"
    log.debug "params = #{params.inspect}"
    
    url =
      get_upload do |f|
        webtmp.store(f, params)
      end

    if url !~ /^\w+:/
      # in case of local storage, url omits the proto, host, port
      url = "http://#{host_with_port}#{url}"
    end

    log.info "finished deferred store operation, url = #{url}"
    out << url
  end
end

# Used by a NetworkEditor instance that was launched from apiweb to save
# back to the database.
# params can include "expiry", "ext", "access_token".
post "/save" do
  ### obsolete?
  protected!

  access_token = params[:access_token]
#  params[:access_token] or not_authorized!

  ###log.info "requested scenario #{id} in editor"
  
#  if can_access?({:type => 'Scenario', 
#                  :id => id}, params[:access_token])

  
  stream_cautiously do |out|
    log.info "saving"
    
    data = request.body.read ###
    log.debug "saving xml = #{data[0..200]}..."
    
    out << "done"
  end
end

post "/save/:key.xml" do |key|
  entry = lookup_apiweb_key(key)
  if !entry
    msg = "No scenario for key=#{key}"
    log.warn msg
    break msg
  end

  log.info "saving by key #{key}"

  stream_cautiously do |out|
    xml = get_upload do |f|
      Nokogiri.XML(f).xpath("/scenario")[0]
    end
    log.debug "saving #{xml.name}"
    
    scenario = import_scenario_xml(xml, entry[:project_id], {})
      ###  need to store import_options and user_id in KEY_TO_ID
    log.info "scenario imported to project #{scenario.project_id}: #{scenario.id}" if scenario 
    
    out << "done: scenario.id = #{scenario.id}"
  end
end
