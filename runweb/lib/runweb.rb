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
end

RUNQ_PORT = Integer(ENV["RUNQ_PORT"]) || 9096
RUNQ_HOST = ENV["RUNQ_HOST"] || 'localhost'
RUNWEB_S3_BUCKET = ENV["RUNWEB_S3_BUCKET"] || "relteq-uploads-dev"

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

Sinatra.register Sinatra::Async

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
  run = resp["runs"][run_idx] ### handle nil
  if run[:frac_complete] == 1.0
    run[:data]
  else
    status 500 ## this isn't really right
    return "not finished: batch_id=#{batch_id}, run_idx=#{run_idx}"
  end
end

# /store?expiry=100&ext=xml
#
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
