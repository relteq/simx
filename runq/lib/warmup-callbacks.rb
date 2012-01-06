module Runq
  class << self
    def update_warmup_callback args
      # anything?
    end
    
    # args is hash with keys:
    #
    #   :worker       row from workers table
    #   :batch_param  batch.param
    #   :run          row from runs table
    #   :req          WorkerFinishedRun
    #
    def finish_warmup_callback args
      batch_param = args[:batch_param]
      run = args[:run]
      req = args[:req]
      
      if not req.data['ok']
        log.warn "warmup run failed: #{run.inspect}"
        
        ### send back message to apiweb
        ### req.data["error"]
        
        return
      end

      log.info "warmup run finished: #{run.inspect}"
      
      filename = req.data['output_urls'][1] # state after warmup
      bucket = req.data['bucket']
      
      case filename
      when /^\w+:/ # looks like url already
        url = filename
      else
        url = "http://s3.amazonaws.com/#{bucket}/#{filename}" ## ok?
      end
      ## this is really hideous
      log.debug "warmup run #{run[:id]} result: #{url}"
      
      orig_batch_id = batch_param["orig_batch_id"]
      dummy_batch_id = run[:batch_id]
      
      runq = req.runq
      database = runq.database

      orig_batches = database[:batches].where(:id => orig_batch_id)
      dummy_batches = database[:batches].where(:id => dummy_batch_id)
      
      orig_batch_param = YAML.load(orig_batches.first[:param])
      orig_batch_param["inputs"][0] = url
      
      orig_batches.update({
        :param => orig_batch_param.to_yaml
      })

      ##dummy_batches.delete?
      
      ## refactor the following with start_batch_without_warmup
      n_runs = orig_batches.first[:n_runs]
      run_ids = n_runs.times.map do |i|
        runq.database[:runs].insert({
          :batch_id     => orig_batch_id,
          :worker_id    => nil,
          :batch_index  => i,
          :frac_complete => 0
        })
      end

      run_ids.each do |run_id|
        break unless runq.dispatch_run run_id
      end
    end
  end
end
