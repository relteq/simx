require 'thin'
require 'sinatra'
require 'eventmachine'
require 'sinatra/async'
require 'sinatra/jsonp'
require 'yaml'
require 'logger'
require 'sequel'
require 'cgi'
require 'haml'
require 'nokogiri'
require 'json'

class MyLogger < Logger
  alias write << # Stupid! See http://groups.google.com/group/rack-devel/browse_thread/thread/ffec93533180e98a
end

class ParameterError < ArgumentError; end

NETWORK_ERRORS = [Errno::ECONNRESET, Errno::ECONNABORTED,
    Errno::ECONNREFUSED,
    Errno::EPIPE, IOError, Errno::ETIMEDOUT]

configure do
  set :raise_errors, false
  set :public, 'public/'
  
  MY_ENV = {}

  if (i = ARGV.index("--log-file"))
    _, MY_ENV[:log_file] = ARGV.slice!(i, 2) ## this is awkward
  end

  if (i = ARGV.index("--log-level"))
    _, MY_ENV[:log_level] = ARGV.slice!(i, 2) ## this is awkward
  end
end
  
configure :production do
  set :show_exceptions, false
  set :dump_errors, false
  set :logging, false
  LOGGER = MyLogger.new(MY_ENV[:log_file], "weekly")
  ##LOGGER.level = MY_ENV[:log_level]
  use Rack::CommonLogger, LOGGER
end

configure :development do
  set :show_exceptions, true
  set :dump_errors, false
  set :logging, true
  LOGGER = MyLogger.new($stderr)
  ##LOGGER.level = MY_ENV[:log_level]
end

configure do
  LOGGER.info "DBweb API service starting"
  
  ne_dir = ENV["NE_DIR"]
  if ne_dir
    if File.directory?(ne_dir)
      set :public, ne_dir
      LOGGER.info "Public dir: #{ne_dir}"
    else
      LOGGER.error "No such dir ENV['NE_DIR']=#{ENV["NE_DIR"].inspect}"
    end
  else
    LOGGER.error "Must set ENV['NE_DIR'] to use network editor"
  end
  
  KEY_TO_ID = {}

  services = [
    ### list service points here
  ]
  
  MY_ENV[:index_page] = [
    "<h3>DBweb Server</h3>",
    services.join("\n"),
  ].flatten.join("\n")
end

helpers do
  def type_translator
    @type_translator ||= { 
      'event_set' => Aurora::EventSet,
      'capacity_profile_set' => Aurora::CapacityProfileSet,
      'split_ratio_profile_set' => Aurora::SplitRatioProfileSet,
      'demand_profile_set' => Aurora::DemandProfileSet,
      'controller_set' => Aurora::ControllerSet,
      'network' => Aurora::Network,
      'scenario'=> Aurora::Scenario 
    }
  end

  def s3
    unless @s3
      require 'aws/s3'

      AWS::S3::Base.establish_connection!(
        :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
        :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
      )
      
      @s3 = true
    end
  end

  # params can include "expiry", "ext"; returns url
  def s3_store data, params
    s3
    expiry_str = params["expiry"]
    expiry =
      begin
        expiry_str && Float(expiry_str)
      rescue => e
        LOGGER.warn e
        nil
      end

    ext = params["ext"]

    require 'digest/md5'
    key = Digest::MD5.hexdigest(data)
    if ext
      if /\./ =~ ext
        ext = ext[/\.([^.]*?)$/, 1]
      end
      key << "." << ext
    end

    # check if key already exists on s3 and don't upload if so
    exists =
      begin
        AWS::S3::S3Object.find key, DBWEB_S3_BUCKET
        true
      rescue AWS::S3::NoSuchKey
        false
      rescue => ex
        LOGGER.debug ex
      end
    
    if exists
      LOGGER.info "Data already exists in S3 at #{DBWEB_S3_BUCKET}/#{key}"
      ## what if expiry is different? update it?
    
    else
      LOGGER.info "Storing in S3 at #{DBWEB_S3_BUCKET}/#{key}"
      LOGGER.debug "expiry=#{expiry.inspect}, data: " + data[0..50]

      opts = {}
      if expiry
        opts["x-amz-meta-expiry"] = Time.at(Time.now + expiry)
        ### need daemon to expire things
      end

      AWS::S3::S3Object.store key, data, DBWEB_S3_BUCKET, opts
    end
    
    url = AWS::S3::S3Object.url_for(key, DBWEB_S3_BUCKET)
    LOGGER.info "url_for returned #{url}"

    return url
  end

  def s3_fetch filename, bucket_name
    return AWS::S3::S3Object.value filename, bucket_name
  end
  
  ### should have rekey option
  def import_xml xml_data
    ###
    [table, id]
  end

  def import_scenario_xml xml_data, project_id
    scenario = Aurora::Scenario.create_from_xml(xml_data)
    network = scenario.network
    scenario.project_id = project_id
    network.project_id = project_id
    network.save
    scenario.save
  end
  
  def export_scenario_xml scenario_id
    Aurora::Scenario[Integer(scenario_id)].to_xml
  rescue => e
    LOGGER.error "export_scenario_xml(#{scenario_id}): #{e}"
    nil
  end
  
  def export_network_xml network_id
    Aurora::Network[Integer(network_id)].to_xml
  rescue => e
    LOGGER.error "export_network_xml(#{network_id}): #{e}"
    nil
  end
  
  def export_wrapped_network_xml network_id
    nw_xml = export_network_xml(network_id)
    LOGGER.debug "nw_xml = #{nw_xml[0..200]}..."
    
    sc_xml = %{\
<?xml version="1.0" encoding="UTF-8"?>
<scenario id='0'>
  <settings>
    <units>US</units>
  </settings>
  #{nw_xml.sub(/.*/, "")}
</scenario>
}

    sc_xml
    
  rescue => e
    LOGGER.error "export_wrapped_network_xml(#{network_id}): #{e}"
    nil
  end
end

DBWEB_S3_BUCKET = ENV["DBWEB_S3_BUCKET"] || "relteq-uploads-dev"
DB_URL = ENV["DBWEB_DB_URL"]
DB = Sequel.connect DB_URL
LOGGER.info "Connected to DB at #{DB_URL}"

require 'db/schema'
Aurora.create_tables? DB

require 'db/model/aurora'
require 'db/import/util'
require 'db/import/scenario'
require 'db/export/scenario'

## don't need this
TRUSTED_ADDRS = Set[*%w{
  127.0.0.1
  ::ffff:127.0.0.1
  localhost
  128.32.129.91
}] ## how to check if some addr resolve to same as localhost?
USERS = [
  %w{ relteq topl5678 }
]

helpers do
  def defer_cautiously
    EM.defer do
      begin
        yield
      rescue Exception => e
        LOGGER.error "error: #{request.url}, params=#{request.params.inspect}"
        LOGGER.error "error text: #{e.message}"
        LOGGER.error "error backtrace: #{e.backtrace.join("\n  ")}"
        status 500
        body { "Internal Error" }
      end
    end
  end

  def protected!
    return ### otherwise, flash credentials don't work??
    response['WWW-Authenticate'] = %(Basic realm="the TOPL Project") and \
    throw(:halt,
          [401, "Not authorized at #{request.env["REMOTE_ADDR"]}\n"]) and \
    return unless authorized?
  end

  def not_authorized!
    throw(:halt,
          [403, "Unauthorized request: Try returning to relteq.com"])
  end

  def authorized?
return true
###
    TRUSTED_ADDRS.include?(request.env["REMOTE_ADDR"]) or begin
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials &&
        USERS.include?(@auth.credentials)
    end
  end

  def can_access?(object, access_token)
    return true if TRUSTED_ADDRS.include?(request.env["REMOTE_ADDR"])

    unexpired_auths = DB[:dbweb_authorizations].filter('expiration > ?', Time.now.utc)
    applicable_to_object = unexpired_auths.filter(
      :object_id => object[:id], 
      :object_type => object[:type],
      :access_token => access_token
    )
    applicable_to_object.all.count == 1 
  end

  def index_page
    MY_ENV[:index_page]
  end
end

Sinatra.register Sinatra::Async

get '/' do
  index_page
end

# See http://kb2.adobe.com/cps/142/tn_14213.html
get '/crossdomain.xml' do
  ## this should just be a static page
  return <<-END
    <?xml version="1.0"?>
    <!DOCTYPE cross-domain-policy SYSTEM
     "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
    <cross-domain-policy>
      <allow-access-from domain="vii.path.berkeley.edu" />
      <allow-access-from domain="path.berkeley.edu" />
      <allow-access-from domain="berkeley.edu" />
      <allow-access-from domain="relteqsystems.com" />
      <allow-access-from domain="relteq-dev.heroku.com" />
      <allow-access-from domain="relteq-devel.heroku.com" />
      <allow-access-from domain="relteq-staging.heroku.com" />
      <allow-access-from domain="relteq.heroku.com" />
      <allow-access-from domain="relteq-db.dyndns.org" />
    </cross-domain-policy>
  END
end

# Import
#
# use /import to import xml data passed by http
# use /import_url to import xml data from a url

## option to async import: need to poll

### add user, group, project id params
aget "/import/scenario/:filename" do |filename|
  protected!
#  params[:access_token] or not_authorized!

  s3
  LOGGER.info "Attempting to import #{params[:bucket]}/#{filename}"

  if can_access?({:type => 'Project',
    :id => params[:to_project]}, params[:access_token])
    defer_cautiously do
      xml_plaintext = s3_fetch(filename, params[:bucket])
      LOGGER.info "loaded XML data from #{filename} for import"
      xml_data = Nokogiri.XML(xml_plaintext).xpath("/scenario")[0]
      Aurora::ImportUtil.rekey!(xml_data)
      scenario = import_scenario_xml(xml_data, params[:to_project])
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

  id, time = KEY_TO_ID[key]
  if !id
    msg = "No scenario for key=#{key}"
    LOGGER.warn msg
    break msg
  end

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

aget "/model/scenario/:id.xml" do |id|
  ###protected!
  access_token = params[:access_token]
  access_token or not_authorized!

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
    url = s3_store(xml, params)
    body url
  end
end

aget "/model/network/:id.xml" do |id|
  ###protected!
  access_token = params[:access_token]
  access_token or not_authorized!
  
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
  
  id, time = KEY_TO_ID[key]
  if !id
    msg = "No network for key=#{key}"
    LOGGER.warn msg
    break msg
  end

  LOGGER.info "requested wrapped network #{id} as xml"
  
  if can_access?({:type => 'Network', 
                  :id => id}, params[:access_token])
    defer_cautiously do
      content_type :xml

      xml = export_wrapped_network_xml(id)
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

      KEY_TO_ID[key] = [id, Time.now]
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

      KEY_TO_ID[key] = [id, Time.now]
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

      KEY_TO_ID[key] = [network_id, Time.now]
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

      KEY_TO_ID[key] = [network_id, Time.now]
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

      KEY_TO_ID[key] = [network_id, Time.now]
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

      KEY_TO_ID[key] = [network_id, Time.now]
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

      KEY_TO_ID[key] = [network_id, Time.now]
      ### clear old ones

      body { haml :flash_edit }
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
  s3

  defer_cautiously do
    LOGGER.info "started deferred store operation"
    
    data = request.body.read
    url = s3_store(data, params)

    LOGGER.info "finished deferred store operation, url = #{url}"
    body url
  end
end

# Used by a NetworkEditor instance that was launched from dbweb to save
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
    
    body "done"
  end
end

not_found do
  "#{request.path_info} not found.\n"
end

error ParameterError do
  status(400)
  "Parameter error: #{request.env['sinatra.error']}.\n"
end

error do
  msg = request.env['sinatra.error']
  LOGGER.error msg.inspect + "\n" + msg.backtrace.join("\n  ")
  "Error: #{msg}\n"
end
