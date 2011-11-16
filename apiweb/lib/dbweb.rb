# Import
#
# use /import to import xml data passed by http
# use /import_url to import xml data from a url

## option to async import: need to poll

### add user, group id params
aget "/import/scenario/:filename" do |filename|
  protected!
#  given[:access_token] or not_authorized!

  log.info "Attempting to import #{given[:bucket]}/#{filename}"

  import_options = {}

  if given[:from_user]
    import_options[:redmine_user_id] = given[:from_user]
  end

  if can_access?({:type => 'Project',
    :id => given[:to_project]}, given[:access_token])
    defer_cautiously do
      xml_plaintext = s3.fetch(filename, given[:bucket])
      log.info "loaded XML data from #{filename} for import"
      xml_data = Nokogiri.XML(xml_plaintext).xpath("/scenario")[0]
      Aurora::ImportUtil.rekey!(xml_data)
      scenario = import_scenario_xml(xml_data, given[:to_project], import_options)
      log.info "scenario imported to project #{scenario.project_id}: #{scenario.id}" if scenario 
  
      if given[:jsoncallback]
        script = jsonp({:success => scenario.id})
        log.debug "returning #{script} as JSONP"
        body { script }
      else
        # For debugging, that callback is an annoying parameter to require
        content_type :json
        body { {:success => scenario.id}.to_json }
      end
    end
  else
    not_authorized!
  end
end

aget "/duplicate/:type/:id" do |type, id|
  received_type = type_translator[type]
  numeric_id = id.to_i
  overrides = {}
  project_dest = given[:to_project]
  overrides[:project_id] = project_dest if project_dest

  if !received_type
    log.error "bad type #{type} for duplicate of #{type}:#{id}"
    raise "bad type for duplicate"
  end

  if can_access?({ :type => received_type.to_s.split('::').last, 
                   :id => numeric_id },
                 given[:access_token])
    defer_cautiously do
      object = received_type[numeric_id]
      if object 
        if given[:deep] && object.respond_to?(:deep_copy)
          copy = object.deep_copy(DB, overrides)
        else
          copy = object.shallow_copy(DB, overrides)
        end
 
        if given[:jsoncallback]
          script = jsonp({:success => copy.id})
          log.debug "returning #{script} as JSONP"
          body { script }
        else
          # For debugging, that callback is an annoying parameter to require
          content_type :json
          body { {:success => copy.id}.to_json }
        end
      else
        body { {:failure => "#{type} not found"}.to_json }
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
apost "/import" do
  protected!

  defer_cautiously do
    xml_data = request.body.read
    log.info "importing #{xml_data.size} bytes of xml data"
    table, id = import_xml(xml_data)
    log.info "finished importing"
    body [table, id].to_yaml
  end
end

# /import_url
# body is the url
# returns [table, id].to_yaml, where table is name of table of top-level
# object of the xml (e.g. scenario) and id is its id in the db.
apost "/import_url" do
  protected!

  defer_cautiously do
    xml_url = request.body.read
    log.info "importing url: #{xml_url.inspect}"
    xml_data = open(xml_url) {|f| f.read} ###
    log.info "read #{xml_data.size} bytes of xml data"
    table, id = import_xml(xml_data)
    log.info "finished importing: #{xml_url.inspect}"
    body [table, id].to_yaml
  end
end


# Export

# Exports the scenario and returns the xml string in the response body, with
# content type application/xml.

aget "/model/scenario-by-key/:key.xml" do |key|
  protected!
# This route is accessed by key, not id, so no need to check this:
#  access_token = given[:access_token]
#  access_token or not_authorized!

  entry = lookup_apiweb_key(key)
  if !entry
    msg = "No scenario for key=#{key}"
    log.warn msg
    break msg
  end

  log.info "requested scenario #{entry[:model_id]} as xml"
  defer_cautiously do
    content_type :xml
    body export_scenario_xml(entry[:model_id])
  end
end

aget "/model/scenario/:id.xml" do |id|
  protected!

  log.info "requested scenario #{id} as xml"

  if can_access?({:type => 'Scenario', 
                  :id => id}, given[:access_token])
    defer_cautiously do
      content_type :xml
      body export_scenario_xml(id)
    end
  else
    not_authorized!
  end
end

# Exports the scenario, uploads the xml string to s3, and returns the url in the
# response body, with content type text/plain.

aget "/model/scenario/:id.url" do |id|
  protected!
  log.info "requested scenario #{id} as url"
  
  defer_cautiously do
    content_type :text
    xml = export_scenario_xml(id)
    given["ext"] = "xml"
    url = s3.store(xml, given)
    body url
  end
end

aget "/model/network/:id.xml" do |id|
  protected!
  
  log.info "requested wrapped network #{id} as xml"
  
  if can_access?({:type => 'Network', 
                  :id => id}, given[:access_token])
    defer_cautiously do
      content_type :xml

      xml = export_network_xml(id)
      if xml
        body xml
      else
        body "dbweb error -- see logs"
      end
    end
  else
    not_authorized!
  end
end


aget "/model/wrapped-network-by-key/:key.xml" do |key|
  protected!
# This route is accessed by key, not id, so no need to check this:
#  access_token = given[:access_token]
#  access_token or not_authorized!
  
  entry = lookup_apiweb_key(key)
  if !entry
    msg = "No network for key=#{key}"
    log.warn msg
    break msg
  end

  log.info "requested wrapped network #{entry[:model_id]} as xml"
  
  defer_cautiously do
    content_type :xml

    xml = export_wrapped_network_xml(entry[:model_id])
    if xml
      body xml
    else
      body "dbweb error -- see logs"
    end
  end
end

# Exports the scenario, uploads the xml string to s3, and returns a html
# response that, when loaded in the client browser, runs our flash app, which
# then loads the url passed to it by fashvars.

aget "/editor/scenario/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested scenario #{id} in editor"
  
  if can_access?({:type => 'Scenario', 
                  :id => id}, given[:access_token])
    defer_cautiously do
      content_type :html

      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "scenario",
        :model_id => id,
        :access_token => access_token
      )
      
      @export_url = "/model/scenario-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]
      
      @dbweb_key = key

      KEY_TO_ID[key] = [id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/network/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested network #{id} in editor"
  
  if can_access?({:type => 'Network', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html

      @network_editor = "/NetworkEditor.swf"

      key = request_apiweb_key(
        :model_class => "network",
        :model_id => id,
        :access_token => access_token
      )
      
      @export_url = "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      @dbweb_key = key

      KEY_TO_ID[key] = [id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/controller_set/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested controller set #{id} in editor"
  
  if can_access?({:type => 'ControllerSet', 
                  :id => id}, access_token)
    defer_cautiously do
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
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/demand_profile_set/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested demand profile set #{id} in editor"
  
  if can_access?({:type => 'DemandProfileSet', 
                  :id => id}, access_token)
    defer_cautiously do
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
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/split_ratio_profile_set/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested split ratio profile set #{id} in editor"
  
  if can_access?({:type => 'SplitRatioProfileSet', 
                  :id => id}, access_token)
    defer_cautiously do
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
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/capacity_profile_set/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested capacity profile set #{id} in editor"
  
  if can_access?({:type => 'CapacityProfileSet', 
                  :id => id}, access_token)
    defer_cautiously do
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
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/event_set/:id.html" do |id|
  protected!
  access_token = given[:access_token]
#  access_token or not_authorized!
  log.info "requested event set #{id} in editor"
  
  if can_access?({:type => 'EventSet', 
                  :id => id}, access_token)
    defer_cautiously do
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
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, given[:to_project]]

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/reports/:report_id/report_xml" do |report_id|
  access_token = given[:access_token]
  log.debug "report_id = #{report_id}"

  if can_access?({:type => 'SimulationBatchReport', 
                  :id => report_id}, access_token)
    defer_cautiously do
      @report = Aurora::SimulationBatchReport[report_id]
      if given[:jsoncallback]
        script = jsonp({:xml => @report.s3_xml})
        body { script }
      else
        # For debugging, that callback is an annoying parameter to require
        content_type :xml
        body { @report.s3_xml }
      end
    end
  else
    not_authorized!
  end
end

# Request s3 storage. +params+ can include "expiry", "ext".
#
# Returns the s3 key, which is a md5 hash of the data, plus the specified file
# extension, if any, which s3 uses to make a content-type header. Expiry is in
# seconds. Default is none. Expiry is not guaranteed, but will not happen before
# the specified number of seconds has elapsed.
apost "/store" do
  protected!
  
  host_with_port = request.host_with_port
  
  defer_cautiously do
    log.info "started deferred store operation"
    
    data = request.body.read
    url = s3.store(data, given)
    if url !~ /^\w+:/
      # in case of local storage, url omits the proto, host, port
      url = "http://#{host_with_port}#{url}"
    end

    log.info "finished deferred store operation, url = #{url}"
    body url
  end
end

aget "/file/:filename" do |filename|
  protected!

  defer_cautiously do
    log.info "deferred fetch of #{filename}"
    body s3.fetch(filename)
  end
end

# Used by a NetworkEditor instance that was launched from apiweb to save
# back to the database.
# given can include "expiry", "ext", "access_token".
apost "/save" do
  protected!

  access_token = given[:access_token]
#  given[:access_token] or not_authorized!

  ###log.info "requested scenario #{id} in editor"
  
#  if can_access?({:type => 'Scenario', 
#                  :id => id}, given[:access_token])

  
  defer_cautiously do
    log.info "saving"
    
    data = request.body.read
    log.debug "saving xml = #{data[0..200]}..."
    
    body "done"
  end
end

apost "/save/:key.xml" do |key|
  entry = lookup_apiweb_key(key)
  if !entry
    msg = "No scenario for key=#{key}"
    log.warn msg
    break msg
  end

  log.info "saving by key #{key}"

  defer_cautiously do
    xml_string = request.body.read
    log.debug "saving xml = #{xml_string[0..200]}..."
    
    xml = Nokogiri.XML(xml_string).xpath("/scenario")[0]
    
    scenario = import_scenario_xml(xml, entry[:project_id], {})
      ###  need to store import_options and user_id in KEY_TO_ID
    log.info "scenario imported to project #{scenario.project_id}: #{scenario.id}" if scenario 
    
    body "done: scenario.id = #{scenario.id}"
  end
end
