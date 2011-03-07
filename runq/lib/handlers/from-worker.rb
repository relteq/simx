require 'yaml'

require 'runq/request'

module Runq
  # Functionality added to requests received at runq from worker.
  module Request::FromWorker
    attr_accessor :sock
    attr_accessor :runq
    
    def log
      @log ||= runq.log
    end
    
    def handle
      raise "Request classes should define #handle."
    end
    
    def have_worker_id
      if worker_id
        true
      else
        log.warn "request did not specify worker_id: #{self.inspect}"
        false
      end
    end
    
    def have_progress
      if progress
        true
      else
        log.warn "request did not specify progress: #{self.inspect}"
        false
      end
    end

    def respond obj
      msg = obj.to_yaml
      sock.send_message msg
      log.info "Sent to worker #{worker_id}:\n#{msg}"
    end
  end
    
  class Request::WorkerReady
    include FromWorker

    attr_reader :worker_id

    def handle
      @worker_id = runq.add_worker(self)
      
      msg = Request::RunqAcceptWorker.new(
        :worker_id => worker_id
      )
      respond msg

      runq.dispatch_to_worker worker_id
    end
  end

  class Request::WorkerReconnect
    include FromWorker

    def handle
      have_worker_id or return
      runq.reconnect_worker(self)
      runq.dispatch_to_worker worker_id # might be ready for another run
    end
  end

  class Request::WorkerUpdate
    include FromWorker
    
    def handle
      have_worker_id or return
      have_progress or return
      runq.update_worker(self)
    end
  end

  class Request::WorkerFinishedRun
    include FromWorker

    def handle
      have_worker_id or return
      runq.finished_worker(self)
      runq.dispatch_to_worker worker_id # ready for another run
    end
  end

  class Request::WorkerAbortedRun
    include FromWorker

    def handle
      have_worker_id or return
      runq.aborted_worker(self)
      runq.dispatch_to_worker worker_id # ready for another run
    end
  end

  class Request::WorkerFailedRun
    include FromWorker

    def handle
      have_worker_id or return
      runq.failed_worker(self)
      runq.dispatch_to_worker worker_id # ready for another run
    end
  end
end
