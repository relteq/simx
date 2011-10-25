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

