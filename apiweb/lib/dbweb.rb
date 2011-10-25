# Import
#
# use /import to import xml data passed by http
# use /import_url to import xml data from a url

## option to async import: need to poll

### add user, group id params
aget "/import/scenario/:filename" do |filename|
  protected!
#  params[:access_token] or not_authorized!

  LOGGER.info "Attempting to import #{params[:bucket]}/#{filename}"

  import_options = {}

  if params[:from_user]
    import_options[:redmine_user_id] = params[:from_user]
  end

  if can_access?({:type => 'Project',
    :id => params[:to_project]}, params[:access_token])
    defer_cautiously do
      xml_plaintext = s3.fetch(filename, params[:bucket])
      LOGGER.info "loaded XML data from #{filename} for import"
      xml_data = Nokogiri.XML(xml_plaintext).xpath("/scenario")[0]
      Aurora::ImportUtil.rekey!(xml_data)
      scenario = import_scenario_xml(xml_data, params[:to_project], import_options)
      LOGGER.info "scenario imported to project #{scenario.project_id}: #{scenario.id}" if scenario 
  
      if params[:jsoncallback]
        script = jsonp({:success => scenario.id})
        LOGGER.debug "returning #{script} as JSONP"
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
  project_dest = params[:to_project]
  overrides[:project_id] = project_dest if project_dest

  if !received_type
    LOGGER.error "bad type #{type} for duplicate of #{type}:#{id}"
    raise "bad type for duplicate"
  end

  if can_access?({ :type => received_type.to_s.split('::').last, 
                   :id => numeric_id },
                 params[:access_token])
    defer_cautiously do
      object = received_type[numeric_id]
      if object 
        if params[:deep] && object.respond_to?(:deep_copy)
          copy = object.deep_copy(DB, overrides)
        else
          copy = object.shallow_copy(DB, overrides)
        end
 
        if params[:jsoncallback]
          script = jsonp({:success => copy.id})
          LOGGER.debug "returning #{script} as JSONP"
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
    LOGGER.info "importing #{xml_data.size} bytes of xml data"
    table, id = import_xml(xml_data)
    LOGGER.info "finished importing"
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
    LOGGER.info "importing url: #{xml_url.inspect}"
    xml_data = open(xml_url) {|f| f.read} ###
    LOGGER.info "read #{xml_data.size} bytes of xml data"
    table, id = import_xml(xml_data)
    LOGGER.info "finished importing: #{xml_url.inspect}"
    body [table, id].to_yaml
  end
end


# Export

# Exports the scenario and returns the xml string in the response body, with
# content type application/xml.

aget "/model/scenario-by-key/:key.xml" do |key|
  ###protected!
# This route is accessed by key, not id, so no need to check this:
#  access_token = params[:access_token]
#  access_token or not_authorized!

  id, time, project_id = KEY_TO_ID[key]
  if !id
    msg = "No scenario for key=#{key}"
    LOGGER.warn msg
    break msg
  end

  LOGGER.info "requested scenario #{id} as xml"
  defer_cautiously do
    content_type :xml
    body export_scenario_xml(id)
  end
end

aget "/model/scenario/:id.xml" do |id|
  ###protected!

  LOGGER.info "requested scenario #{id} as xml"

  if can_access?({:type => 'Scenario', 
                  :id => id}, params[:access_token])
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
  LOGGER.info "requested scenario #{id} as url"
  
  defer_cautiously do
    content_type :text
    xml = export_scenario_xml(id)
    params["ext"] = "xml"
    url = s3.store(xml, params)
    body url
  end
end

aget "/model/network/:id.xml" do |id|
  ###protected!
  
  LOGGER.info "requested wrapped network #{id} as xml"
  
  if can_access?({:type => 'Network', 
                  :id => id}, params[:access_token])
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
  ###protected!
# This route is accessed by key, not id, so no need to check this:
#  access_token = params[:access_token]
#  access_token or not_authorized!
  
  id, time, project_id = KEY_TO_ID[key]
  if !id
    msg = "No network for key=#{key}"
    LOGGER.warn msg
    break msg
  end

  LOGGER.info "requested wrapped network #{id} as xml"
  
  defer_cautiously do
    content_type :xml

    xml = export_wrapped_network_xml(id)
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
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested scenario #{id} in editor"
  
  if can_access?({:type => 'Scenario', 
                  :id => id}, params[:access_token])
    defer_cautiously do
      content_type :html

      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + "scenario" + id + Time.now.to_s)
      @s3_url = ### change name!
        "/model/scenario-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]
      
      @dbweb_key = key

      KEY_TO_ID[key] = [id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/network/:id.html" do |id|
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested network #{id} in editor"
  
  if can_access?({:type => 'Network', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html

      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + "network" + id + Time.now.to_s)
      @s3_url = ### change name!
        "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      @dbweb_key = key

      KEY_TO_ID[key] = [id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/controller_set/:id.html" do |id|
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested controller set #{id} in editor"
  
  if can_access?({:type => 'ControllerSet', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html
      cs = Aurora::ControllerSet[Integer(id)]
      network_id = cs.network_id

      @focus = 'controller_set'
      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + 
        "network" + 
        network_id.to_s + 
        Time.now.to_s
      )
      @s3_url = ### change name!
        "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/demand_profile_set/:id.html" do |id|
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested demand profile set #{id} in editor"
  
  if can_access?({:type => 'DemandProfileSet', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html
      dps = Aurora::DemandProfileSet[Integer(id)]
      network_id = dps.network_id

      @focus = 'demand-profile-set'
      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + 
        "network" + 
        network_id.to_s + 
        Time.now.to_s
      )
      @s3_url = ### change name!
        "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/split_ratio_profile_set/:id.html" do |id|
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested split ratio profile set #{id} in editor"
  
  if can_access?({:type => 'SplitRatioProfileSet', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html
      srps = Aurora::SplitRatioProfileSet[Integer(id)]
      network_id = srps.network_id

      @focus = 'split-ratio-profile-set'
      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + 
        "network" + 
        network_id.to_s + 
        Time.now.to_s
      )
      @s3_url = ### change name!
        "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/capacity_profile_set/:id.html" do |id|
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested capacity profile set #{id} in editor"
  
  if can_access?({:type => 'CapacityProfileSet', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html
      cps = Aurora::CapacityProfileSet[Integer(id)]
      network_id = cps.network_id

      @focus = 'capacity-profile-set'
      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + 
        "network" + 
        network_id.to_s + 
        Time.now.to_s
      )
      @s3_url = ### change name!
        "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/editor/event_set/:id.html" do |id|
###  protected!
  access_token = params[:access_token]
#  access_token or not_authorized!
  LOGGER.info "requested event set #{id} in editor"
  
  if can_access?({:type => 'EventSet', 
                  :id => id}, access_token)
    defer_cautiously do
      content_type :html
      es = Aurora::EventSet[Integer(id)]
      network_id = es.network_id

      @focus = 'event-set'
      @network_editor = "/NetworkEditor.swf"

      key = Digest::MD5.hexdigest((access_token||"") + 
        "network" + 
        network_id.to_s + 
        Time.now.to_s
      )
      @s3_url = ### change name!
        "/model/wrapped-network-by-key/#{key}.xml"
      @gmap_key = ENV["GMAP_KEY"]

      KEY_TO_ID[key] = [network_id, Time.now, params[:to_project]]
      ### clear old ones

      body { haml :flash_edit }
    end
  else
    not_authorized!
  end
end

aget "/reports/:report_id/report_xml" do |report_id|
  access_token = params[:access_token]
  LOGGER.debug "report_id = #{report_id}"

  if can_access?({:type => 'SimulationBatchReport', 
                  :id => report_id}, access_token)
    defer_cautiously do
      @report = Aurora::SimulationBatchReport[report_id]
      if params[:jsoncallback]
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

# Request s3 storage; returns the s3 key, which is
# a md5 hash of the data, plus the specified file extension, if any, which
# s3 uses to make a content-type header. Expiry is in seconds. Default is
# none. Expiry is not guaranteed, but will not happen before the specified
# number of seconds has elapsed.
apost "/store" do
  protected!

  defer_cautiously do
    LOGGER.info "started deferred store operation"
    
    data = request.body.read
    url = s3.store(data, params)

    LOGGER.info "finished deferred store operation, url = #{url}"
    body url
  end
end

aget "/file/:filename" do |filename|
  protected!

  defer_cautiously do
    LOGGER.info "deferred fetch of #{filename}"
    body s3.fetch(filename)
  end
end

# Used by a NetworkEditor instance that was launched from apiweb to save
# back to the database.
# params can include "expiry", "ext", "access_token".
apost "/save" do
  ###protected!

  access_token = params[:access_token]
#  params[:access_token] or not_authorized!

  ###LOGGER.info "requested scenario #{id} in editor"
  
#  if can_access?({:type => 'Scenario', 
#                  :id => id}, params[:access_token])

  
  defer_cautiously do
    LOGGER.info "saving"
    
    data = request.body.read
    LOGGER.debug "saving xml = #{data[0..200]}..."
    
    body "done"
  end
end

apost "/save/:key.xml" do |key|
  id, time, project_id = KEY_TO_ID[key]
  if !id
    msg = "No scenario for key=#{key}"
    LOGGER.warn msg
    break msg
  end

  LOGGER.info "saving by key #{key}"

  defer_cautiously do
    xml_string = request.body.read
    LOGGER.debug "saving xml = #{xml_string[0..200]}..."
    
    xml = Nokogiri.XML(xml_string).xpath("/scenario")[0]
    
    scenario = import_scenario_xml(xml, project_id, {})
      ###  need to store import_options and user_id in KEY_TO_ID
    LOGGER.info "scenario imported to project #{scenario.project_id}: #{scenario.id}" if scenario 
    
    body "done: scenario.id = #{scenario.id}"
  end
end
