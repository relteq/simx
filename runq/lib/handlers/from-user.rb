require 'yaml'

require 'runq/request'
require 'runq/warmup-callbacks'

module Runq
  # Functionality added to requests received at runq from user (runweb).
  module Request::FromUser
    attr_accessor :sock
    attr_accessor :runq
    
    def log
      @log ||= runq.log
    end
    
    def handle
      raise "Request classes should define #handle."
    end
    
    def respond obj
      msg = obj.to_yaml
      sock.send_message msg
      log.debug "Sent to user:\n#{msg}"
    end

    def respond_ok msg, h={}
      respond({
        "status"  => "ok",
        "message" => msg
      }.merge h)
    end
    
    def respond_error msg, h={}
      respond({
        "status"  => "error",
        "message" => msg
      }.merge h)
    end
  end

  class Request::StartBatch
    include Request::FromUser

    def handle
      batch_id = runq.database[:batches] << {
        :name           => name,
        :group          => group,
        :user           => user,
        :engine         => engine,
        :n_runs         => n_runs,
        :param          => param.to_yaml,

        :start_time     => Time.now,
        :execution_time => nil,
        :n_complete     => 0
      }
      respond_ok("batch started",
        "batch_id" => batch_id
      )

      if engine == "simulator"
        time_range_xml = param["inputs"][1] ## shouldn't hard-code this
        
        if time_range_xml
          begin_time =
            (Integer(time_range_xml[/begin_time="(\d+)/, 1]) rescue nil)
          
          if begin_time and begin_time > 0
            start_batch_with_warmup batch_id, begin_time
            return
          end
        end
      end

      start_batch_without_warmup batch_id
    end
    
    def start_batch_with_warmup batch_id, begin_time
      warmup_param = Marshal.load(Marshal.dump(param))
      
      warmup_param["orig_batch_id"] = batch_id
      
      warmup_param["inputs"][1].sub!(/begin_time="\d+"/,
        "begin_time=\"0\"")
      warmup_param["inputs"][1].sub!(/duration="\d+"/,
        "duration=\"#{begin_time}\"")

      warmup_param["output_types"][1] = "application/xml"

      dummy_batch_id = runq.database[:batches] << {
        :name           => name + " dummy",
        :group          => group,
        :user           => user,
        :engine         => engine,
        :n_runs         => 1,
        :param          => warmup_param.to_yaml,

        :start_time     => Time.now,
        :execution_time => nil,
        :n_complete     => 0
      }

      run_id = runq.database[:runs] << {
        :batch_id         => dummy_batch_id,
        :worker_id        => nil,
        :batch_index      => 0,
        :frac_complete    => 0,
        :update_callback  => 'update_warmup_callback',
        :finish_callback  => 'finish_warmup_callback'
      }
      
      runq.dispatch_run run_id
    end
    
    def start_batch_without_warmup batch_id
      run_ids = n_runs.times.map do |i|
        runq.database[:runs] << {
          :batch_id     => batch_id,
          :worker_id    => nil,
          :batch_index  => i,
          :frac_complete => 0
        }
      end

      run_ids.each do |run_id|
        break unless runq.dispatch_run run_id
      end
    end
  end

  class Request::UserStatus
    include Request::FromUser

    def handle
      batches = runq.database[:batches].where(:user => user_id).all
      respond_ok "got user #{user_id} status", "batches" => batches
    end
  end

  class Request::BatchStatus
    include Request::FromUser

    def handle
      batch = runq.database[:batches].where(:id => batch_id).first
      runs = runq.database[:runs].where(:batch_id => batch_id).all
      respond_ok "got batch #{batch_id} status",
        "batch" => batch,
        "runs" => runs
    end
  end

  class Request::BatchList
    include Request::FromUser

    def handle
      batches = runq.database[:batches].all
      respond_ok "got batch list", "batches" => batches
    end
  end

  class Request::WorkerList
    include Request::FromUser

    def handle
      workers = runq.database[:workers].all
      workers.each do |worker|
        known = runq.socket_for_worker.key? worker[:id]
        s = runq.socket_for_worker[worker[:id]]
        worker[:connected] = known && s && !s.closed?
      end
      respond_ok "got worker list", "workers" => workers
    end
  end

  class Request::WorkerStatus
    include Request::FromUser

    ### TODO
  end

  class Request::RunStatus
    include Request::FromUser

    ### TODO
  end
  
  ### Abort run / batch
end
