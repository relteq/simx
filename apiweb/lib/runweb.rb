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
  log.info "StartBatch request:\n#{s}"
  h = YAML.load(s)
  req = Runq::Request::StartBatch.new h
  resp = send_request_and_recv_response req
  resp.to_yaml
end

# UserStatus
get '/user/:id' do
  protected!
  id = Integer(params[:id])
  log.info "UserStatus request, id=#{id}"
  req = Runq::Request::UserStatus.new :user_id => id
  resp = send_request_and_recv_response req
  resp.to_yaml
end

# BatchStatus
get '/batch/:id' do
  protected!
  id = Integer(params[:id])
  log.info "BatchStatus request, id=#{id}"
  req = Runq::Request::BatchStatus.new :batch_id => id
  resp = send_request_and_recv_response req
  resp.to_yaml
end

# BatchList
get %r{^/batch(?:es)?$} do
  protected!
  log.info "BatchList request"
  req = Runq::Request::BatchList.new
  resp = send_request_and_recv_response req
  resp.to_yaml
    ## check for error and use that to distinguish between error here or
    ## in the runq daemon
end

# WorkerList
get %r{^/workers?$} do
  protected!
  log.info "WorkerList request"
  req = Runq::Request::WorkerList.new
  resp = send_request_and_recv_response req
  resp.to_yaml
end

### WorkerStatus

### RunStatus

# checks if batch is all done, optionally waiting some seconds
# returns YAML string "--- true" or "--- false".
get "/batch/:batch_id/done" do |batch_id|
  protected!
  
  batch_id = Integer(batch_id)
  wait = params[:wait] && Integer(params[:wait])
  log.info "Batch done request, batch_id=#{batch_id}, wait=#{wait}"
  
  req = Runq::Request::BatchStatus.new :batch_id => batch_id, :wait => wait
  
  stream_cautiously do |out|
    resp = send_request_and_recv_response req
    batch = resp["batch"]
    if batch
      n_runs = batch[:n_runs]
      n_complete = batch[:n_complete]
      done = n_runs == n_complete
      log.info "Batch done response, batch_id=#{batch_id}, wait=#{wait}: " +
        "#{done.inspect}"
      out << done.to_yaml
    else
      log.info "no such batch: #{batch_id}"
      status 404
      out << "no such batch"
      ### these responses are not consistent with the "status"=>"ok" stuff
    end
  end
end

# checks batch status, optionally waiting some seconds for the batch to finish
# returns YAML object {}.
get "/batch/:batch_id/status" do |batch_id|
  protected!
  
  batch_id = Integer(batch_id)
  wait = params[:wait] && Integer(params[:wait])
  log.info "Batch status request, batch_id=#{batch_id}, wait=#{wait}"
  
  req = Runq::Request::BatchStatus.new :batch_id => batch_id, :wait => wait
  
  stream_cautiously do |out|
    resp = send_request_and_recv_response req
    log.debug "batch status response: #{resp.inspect}"
    batch = resp["batch"]
    if batch
      batch[:done] = (batch[:n_runs] == batch[:n_complete])
      log.info "Batch status response, batch_id=#{batch_id}, wait=#{wait}: " +
        "#{batch.inspect}"
      out << batch.to_yaml
    else
      log.info "no such batch: #{batch_id}"
      status 404
      out << "no such batch"
      ### these responses are not consistent with the "status"=>"ok" stuff
    end
  end
end

# checks if a run is done
# returns YAML string "--- true" or "--- false".
get "/batch/:batch_id/run/:run_idx/done" do
  protected!
  batch_id = Integer(params[:batch_id])
  run_idx = Integer(params[:run_idx])
  log.info "Run done request, batch_id=#{batch_id}, run_idx=#{run_idx}"
  req = Runq::Request::BatchStatus.new :batch_id => batch_id
  resp = send_request_and_recv_response req
  run = resp["runs"][run_idx] ### handle resp["runs"] == nil
  (run[:frac_complete] == 1.0).to_yaml
  ### these responses are not consistent with the "status"=>"ok" stuff
end

# when run done, read result
get "/batch/:batch_id/run/:run_idx/result" do
  protected!
  batch_id = Integer(params[:batch_id])
  run_idx = Integer(params[:run_idx])
  log.info "Run done request, batch_id=#{batch_id}, run_idx=#{run_idx}"
  req = Runq::Request::BatchStatus.new :batch_id => batch_id
  resp = send_request_and_recv_response req
  run = resp["runs"][run_idx] ### handle resp["runs"] == nil
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

