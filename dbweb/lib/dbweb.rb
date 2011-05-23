require 'sinatra'
require 'sinatra/async'
require 'yaml'
require 'logger'
require 'sequel'

require 'db/import/scenario'
require 'db/export/scenario'

class MyLogger < Logger
  alias write << # Stupid! See http://groups.google.com/group/rack-devel/browse_thread/thread/ffec93533180e98a
end

class ParameterError < ArgumentError; end

NETWORK_ERRORS = [Errno::ECONNRESET, Errno::ECONNABORTED,
    Errno::ECONNREFUSED,
    Errno::EPIPE, IOError, Errno::ETIMEDOUT]

configure do
  set :raise_errors, false
  
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
  
  services = [
    ### list service points here
  ]
  
  MY_ENV[:index_page] = [
    "<h3>DBweb Server</h3>",
    services.join("\n"),
  ].flatten.join("\n")
end

helpers do
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
  
  ### should have rekey option
  def import_xml xml_data
    ###
    [table, id]
  end
end

DBWEB_S3_BUCKET = ENV["DBWEB_S3_BUCKET"] || "relteq-uploads-dev"
DB_URL = ENV["DBWEB_DB_URL"]

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
  def protected!
return ### otherwise, flash credentials don't work??
    response['WWW-Authenticate'] = %(Basic realm="the TOPL Project") and \
    throw(:halt,
          [401, "Not authorized at #{request.env["REMOTE_ADDR"]}\n"]) and \
    return unless authorized?
  end

  def authorized?
    TRUSTED_ADDRS.include?(request.env["REMOTE_ADDR"]) or begin
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials &&
        USERS.include?(@auth.credentials)
    end
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
    </cross-domain-policy>
  END
end

# Import
#
# use /import to import xml data passed by http
# use /import_url to import xml data from a url

## option to async import: need to poll

### add user, group, project id params

# /import
# body is the xml data
# returns [table, id].to_yaml, where table is name of table of top-level
# object of the xml (e.g. scenario) and id is its id in the db.
apost "/import" do
  protected!

  EM.defer do
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

  EM.defer do
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
#
# use /export to export xml data via http
# use /export_s3 to export xml data to s3, returning the key

# Request s3 storage; returns the s3 key, which is
# a md5 hash of the data, plus the specified file extension, if any, which
# s3 uses to make a content-type header. Expiry is in seconds. Default is
# none. Expiry is not guaranteed, but will not happen before the specified
# number of seconds has elapsed.
apost "/store" do
  protected!
  s3

  EM.defer do
    LOGGER.info "started deferred store operation"

    expiry_str = params["expiry"]
    expiry =
      begin
        expiry_str && Float(expiry_str)
      rescue => e
        LOGGER.warn e
        nil
      end

    ext = params["ext"]
    data = request.body.read

    require 'digest/md5'
    key = Digest::MD5.hexdigest(data)
    if ext
      if /\./ =~ ext
        ext = ext[/\.([^.]*?)$/, 1]
      end
      key << "." << ext
    end

    LOGGER.debug "Storing at #{key} with expiry=#{expiry.inspect}: " +
      data[0..50]

    opts = {
      :access => :public_read
    }
    if expiry
      opts["x-amz-meta-expiry"] = Time.at(Time.now + expiry)
      ### need daemon to expire things
    end

    AWS::S3::S3Object.store key, data, RUNWEB_S3_BUCKET, opts

    LOGGER.info "finished deferred store operation"
    body "https://s3.amazonaws.com/#{RUNWEB_S3_BUCKET}/#{key}"
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
