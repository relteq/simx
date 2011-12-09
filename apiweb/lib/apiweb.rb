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
require 'digest/md5'

require 'simx/mtcp'
require 'runq/request'

class MyLogger < Logger
  alias write <<
    # Stupid! See http://groups.google.com/group/rack-devel/browse_thread/thread/ffec93533180e98a
end

class ParameterError < ArgumentError; end

NETWORK_ERRORS = [Errno::ECONNRESET, Errno::ECONNABORTED,
    Errno::ECONNREFUSED, Errno::EPIPE, IOError, Errno::ETIMEDOUT]

configure do
  set :raise_errors, false
  set :public_folder, 'public/'
  
  MY_ENV = {}

  if (i = ARGV.index("--log-file"))
    _, MY_ENV[:log_file] = ARGV.slice!(i, 2) ## this is awkward
  end

  if (i = ARGV.index("--log-level"))
    _, MY_ENV[:log_level] = ARGV.slice!(i, 2) ## this is awkward
  end

  if (i = ARGV.index("--runq-port"))
    _, ENV["RUNQ_PORT"] = ARGV.slice!(i, 2) ## this is awkward
  end

  if (i = ARGV.index("--runq-host"))
    _, ENV["RUNQ_HOST"] = ARGV.slice!(i, 2) ## this is awkward
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
  LOGGER.info "Simx api web service starting"
  
  KEY_TO_ID = {}

  services = [
    ## list service points here
  ]
  
  MY_ENV[:index_page] = [
    "<h3>APIweb Server</h3>",
    services.join("\n"),
  ].flatten.join("\n")
end

helpers do
  def log
    LOGGER
  end
end

## this should be in config block?
SIMX_S3_BUCKET = ENV["SIMX_S3_BUCKET"] || "relteq-uploads-dev"
DB_URL = ENV["SIMX_DB_URL"]
DB = Sequel.connect DB_URL
if ENV["APIWEB_LOG_SQL"]
  DB.loggers << LOGGER
end
LOGGER.info "Connected to DB at #{DB_URL}"

require 'db/schema'
Aurora.create_tables? DB

require 'db/model/aurora'
require 'db/import/util'
require 'db/import/scenario'
require 'db/export/scenario'
require 'db/import/context'

## don't need this
TRUSTED_ADDRS = Set[*%w{
  127.0.0.1
  ::ffff:127.0.0.1
  localhost
  128.32.129.91
}] ## how to check if some addr resolve to same as localhost?
USERS = [
  %w{ relteq topltopl },
  %w{ topl topltopl },
  %w{ d4 topltopl }
]

RUNQ_PORT = Integer(ENV["RUNQ_PORT"] || 9096)
RUNQ_HOST = ENV["RUNQ_HOST"] || 'localhost'

Sinatra.register Sinatra::Async

require 'apiweb/sinatra-hack'
require 'apiweb/db-helpers'
require 'apiweb/run-helpers'
require 'apiweb/web-helpers'

get '/' do
  index_page
end

# See http://kb2.adobe.com/cps/142/tn_14213.html
#get '/crossdomain.xml' do
# this is now a static page
## do we still need this?

require 'apiweb/dbweb'
require 'apiweb/runweb'

not_found do
  "#{request.path_info} not found.\n"
end

error ParameterError do
  status(400)
  "Parameter error: #{request.env['sinatra.error']}.\n"
end

error do
  msg = request.env['sinatra.error']
  log.error msg.inspect + "\n" + msg.backtrace.join("\n  ")
  "Error: #{msg}\n"
end
