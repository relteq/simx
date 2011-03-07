require 'sinatra'
require 'yaml'
require 'logger'

require 'simx/mtcp'
require 'runq/request'

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
  LOGGER.info "Runweb API service starting"
  
  services = [
    ### list service points here
  ]
  
  MY_ENV[:index_page] = [
    "<h3>Runweb Server</h3>",
    services.join("\n"),
  ].flatten.join("\n")
end

helpers do
  def send_request_and_recv_response req
    reply = nil
    MTCP::Socket.open(RUNQ_HOST, RUNQ_PORT) do |sock|
      sock.send_message req.to_yaml
      reply_str = sock.recv_message
#LOGGER.info "reply_str = #{reply_str.inspect}"
      reply = YAML.load(reply_str)
    end

    if reply["status"] == "ok"
      LOGGER.info reply["message"]
    else
      LOGGER.warn reply["message"]
    end

    return reply.to_yaml
  
  rescue *NETWORK_ERRORS => e
    status 500
    return {
      "status" => "error",
      "message" => e.message,
    }.to_yaml
  end
end

RUNQ_PORT = ENV["RUNQ_PORT"] || 8096
RUNQ_HOST = ENV["RUNQ_HOST"] || 'localhost'

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

get '/' do
  index_page
end

# StartBatch. Body is yaml hash with string keys:
#
#  name:           test123
#  engine:         dummy
#  group:          topl
#  user:           topl
#  n_runs:         3
#  param:          10
#
# See README for more details.
#
post '/batch/new' do
  protected!
  s = request.body.read
  LOGGER.info "StartBatch request:\n#{s}"
  h = YAML.load(s)
  req = Runq::Request::StartBatch.new h
  send_request_and_recv_response req
end

# UserStatus
get '/user/:id' do
  protected!
  id = Integer(params[:id])
  LOGGER.info "UserStatus request, id=#{id}"
  req = Runq::Request::UserStatus.new :user_id => id
  send_request_and_recv_response req
end

# BatchStatus
get '/batch/:id' do
  protected!
  id = Integer(params[:id])
  LOGGER.info "BatchStatus request, id=#{id}"
  req = Runq::Request::BatchStatus.new :batch_id => id
  send_request_and_recv_response req
end

# BatchList
get %r{^/batch(?:es)?$} do
  protected!
  LOGGER.info "BatchList request"
  req = Runq::Request::BatchList.new
  send_request_and_recv_response req
    ## check for error and use that to distinguish between error here or
    ## in the runq daemon
end

# WorkerList
get %r{^/workers?$} do
  protected!
  LOGGER.info "WorkerList request"
  req = Runq::Request::WorkerList.new
  send_request_and_recv_response req
end

### WorkerStatus

### RunStatus

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
