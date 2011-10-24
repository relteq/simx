require 'sinatra'
require 'sinatra/async'
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

    return reply
  
  rescue *NETWORK_ERRORS => e
    status 500
    return {
      "status" => "error",
      "message" => e.message,
    }
  end
end

RUNQ_PORT = Integer(ENV["RUNQ_PORT"]) || 9096
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
  resp = send_request_and_recv_response req
  resp.to_yaml
end

# UserStatus
get '/user/:id' do
  protected!
  id = Integer(params[:id])
  LOGGER.info "UserStatus request, id=#{id}"
  req = Runq::Request::UserStatus.new :user_id => id
  resp = send_request_and_recv_response req
  resp.to_yaml
end

# BatchStatus
get '/batch/:id' do
  protected!
  id = Integer(params[:id])
  LOGGER.info "BatchStatus request, id=#{id}"
  req = Runq::Request::BatchStatus.new :batch_id => id
  resp = send_request_and_recv_response req
  resp.to_yaml
end

# BatchList
get %r{^/batch(?:es)?$} do
  protected!
  LOGGER.info "BatchList request"
  req = Runq::Request::BatchList.new
  resp = send_request_and_recv_response req
  resp.to_yaml
    ## check for error and use that to distinguish between error here or
    ## in the runq daemon
end

# WorkerList
get %r{^/workers?$} do
  protected!
  LOGGER.info "WorkerList request"
  req = Runq::Request::WorkerList.new
  resp = send_request_and_recv_response req
  resp.to_yaml
end

### WorkerStatus

### RunStatus

# checks if batch is all done
# returns YAML string "--- true" or "--- false".
get "/batch/:batch_id/done" do
  protected!
  batch_id = Integer(params[:batch_id])
  LOGGER.info "Batch done request, batch_id=#{batch_id}"
  req = Runq::Request::BatchStatus.new :batch_id => batch_id
  resp = send_request_and_recv_response req
  batch = resp["batch"]
  if batch
    n_runs = batch[:n_runs]
    n_complete = batch[:n_complete]
    (n_runs == n_complete).to_yaml
  else
    status 404
    return "no such batch"
    ### these responses are not consistent with the "status"=>"ok" stuff
  end
end

# checks if a run is done
# returns YAML string "--- true" or "--- false".
get "/batch/:batch_id/run/:run_idx/done" do
  protected!
  batch_id = Integer(params[:batch_id])
  run_idx = Integer(params[:run_idx])
  LOGGER.info "Run done request, batch_id=#{batch_id}, run_idx=#{run_idx}"
  req = Runq::Request::BatchStatus.new :batch_id => batch_id
  resp = send_request_and_recv_response req
  run = resp["runs"][run_idx] ### handle nil
  (run[:frac_complete] == 1.0).to_yaml
  ### these responses are not consistent with the "status"=>"ok" stuff
end

# when run done, read result
get "/batch/:batch_id/run/:run_idx/result" do
  protected!
  batch_id = Integer(params[:batch_id])
  run_idx = Integer(params[:run_idx])
  LOGGER.info "Run done request, batch_id=#{batch_id}, run_idx=#{run_idx}"
  req = Runq::Request::BatchStatus.new :batch_id => batch_id
  resp = send_request_and_recv_response req
  run = resp["runs"][run_idx]
  if run
    if run[:frac_complete] == 1.0
      run[:data]
    else
      # note: /^not finished/ is used by network editor to test for failure
      "not finished: batch_id=#{batch_id}, run_idx=#{run_idx}, " +
        "run_data=#{run[:data].inspect}" ## ok?
    end
  else
    "Error: No such run." ## 404?
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
