module Runq
  # Base for request classes used by several distinct components
  # of the distributed system: runweb, runq, and workers. Note that
  # runq adds, for its own user, extra functionality to the classes in
  # request-handlers.rb.
  class Request
    def initialize h={}
      h.each do |k,v|
        send "#{k}=", v
      end
    end
    
    # ------------------------
    # :section: worker requests
    #
    # Requests from worker to runq.
    #
    # ------------------------

    # Worker is ready to start accepting runs.
    # Worker process stores worker_id from response.
    class WorkerReady < Request
      attr_accessor :host
      attr_accessor :pid
      attr_accessor :group
      attr_accessor :user
      attr_accessor :engine
      attr_accessor :cost
      attr_accessor :speed
      attr_accessor :priority
    end
    
    # Worker has reconnected to the server, possibly while continuing to
    # execute a run. Thw worker has already been assigned an id during a
    # previous connection.
    class WorkerReconnect < Request
      attr_accessor :worker_id
    end
    
    # Worker is checking in periodically or after reconnecting socket.
    class WorkerUpdate < Request
      attr_accessor :worker_id
      attr_accessor :progress
      
      # Optional message (used for explicit status request).
      attr_accessor :message
      
      def frac_complete
        case progress
        when 0..1
          progress
        when :waiting, :failed, :aborted
          0
        when :finished
          1
        end
      end
    end
    
    # Worker has finished a run and is now ready for another.
    class WorkerFinishedRun < Request
      attr_accessor :worker_id
      attr_accessor :data
    end
    
    # Worker has aborted a run at the request of runq.
    class WorkerAbortedRun < Request
      attr_accessor :worker_id
    end
    
    # Worker has stopped a run due to a failure (e.g. bad input to computation).
    class WorkerFailedRun < Request
      attr_accessor :worker_id
      attr_accessor :message
    end
    
    # ------------------------
    # :section: runq requests
    #
    # Requests from runq to worker.
    #
    # ------------------------
    
    class RunqAcceptWorker < Request
      attr_accessor :worker_id
    end
    
    class RunqAssignRun < Request
      # Engine-specified parameter
      attr_accessor :param
      
      # Index of this run in batch (may be used in combination with param
      # to select run-specific inputs).
      attr_accessor :batch_index
    end
    
    class RunqGetStatus < Request
    end
    
    class RunqAbortRun < Request
    end
    
    # ------------------------
    # :section: user requests
    #
    # Requests from user (e.g. runweb) to runq.
    #
    # ------------------------

    # User requests runq daemon to start a batch of runs
    # If +scenario_id+, export the scenario from the database.
    # Otherwise, use +scenario_xml+ (aurora.xsd).
    class StartBatch < Request
      attr_accessor :name
      attr_accessor :group
      attr_accessor :user
      attr_accessor :engine
      attr_accessor :n_runs
      attr_accessor :param
    end
    
    # For a given user, get active batches.
    class UserStatus < Request
      attr_accessor :user_id
    end
    
    # For a given batch, get all runs (waiting, running, and finished).
    class BatchStatus < Request
      attr_accessor :batch_id
    end
    
    # Return list of all known batches.
    class BatchList < Request
    end
    
    # Return list of all known workers, adding the :connected key to
    # each one, depending on whether we have a socket to it.
    class WorkerList < Request
    end
    
    # For a given worker, get run and cpu stats.
    class WorkerStatus < Request
      ### TODO
    end
    
    # For a given run, get status.
    class RunStatus < Request
      ### TODO
    end
    
    ### Abort batch / run.
  end
end
