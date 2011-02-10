require 'yaml'

require 'runq/db'

module Runq
  # A request should not be considered to take effect until a response is
  # received.
  class Request
    attr_accessor :sock
    attr_accessor :runq 
    
    def initialize h={}
      h.each do |k,v|
        send "#{k}=", v
      end
    end
    
    def handle; raise; end
    
    def respond obj
      sock.send_message obj.to_yaml
    end
    
    def respond_ok msg, h={}
      respond({
        "status"  => "ok",
        "message" => msg
      }.merge h)
      runq.log.info msg
    end
    
    def respond_error msg, h={}
      respond({
        "status"  => "error",
        "message" => msg
      }.merge h)
      runq.log.error msg
    end
    
    # Worker is ready to start accepting runs.
    # Worker process stores worker_id from response.
    class WorkerReady < Request
      attr_accessor :host
      attr_accessor :pid
      attr_accessor :group
      attr_accessor :user
      attr_accessor :engine
      attr_accessor :cost
      
      def handle
        worker_id = runq.add_worker(self)
        respond_ok("worker added",
          "worker_id" => worker_id
        )
        runq.dispatch_to_worker worker_id
      end
    end
    
    # Worker has reconnected to the server, possibly while continuing to
    # execute a run.
    class WorkerReconnect < Request
      attr_accessor :worker_id
      
      def handle
        unless worker_id
          respond_error "request did not specify worker_id: #{self.inspect}"
          return
        end
        
        runq.reconnect_worker(self)
        respond_ok "reconnected to worker #{worker_id}"
        
        runq.dispatch_to_worker worker_id # might be ready for another run
      end
    end
    
    # Worker is checking in periodically or after reconnecting socket.
    class WorkerUpdate < Request
      attr_accessor :worker_id
      attr_accessor :frac_complete
      
      def handle
        unless worker_id
          respond_error "request did not specify worker_id: #{self.inspect}"
          return
        end
        
        unless frac_complete
          respond_error "request did not specify frac_complete: #{self.inspect}"
          return
        end

        runq.update_worker(self)
        respond_ok "worker updated"
      end
    end
    
    # Worker has finished a run and is now ready for another.
    class WorkerFinishedRun < Request
      attr_accessor :worker_id
      
      def handle
        unless worker_id
          respond_error "request did not specify worker_id: #{self.inspect}"
          return
        end
        
        runq.finished_worker(self)
        respond_ok "run finished"
        
        runq.dispatch_to_worker worker_id # ready for another run
      end
    end
    
    # User requests runq daemon to start a batch of runs
    # If +scenario_id+, export the scenario from the database.
    # Otherwise, use +scenario_xml+ (aurora.xsd).
    class StartBatch < Request
      attr_accessor :scenario_id
      attr_accessor :scenario_xml
      attr_accessor :name
      attr_accessor :n_runs
      attr_accessor :mode
      attr_accessor :engine
      attr_accessor :b_time
      attr_accessor :duration
      attr_accessor :control
      attr_accessor :qcontrol
      attr_accessor :events
      attr_accessor :group
      attr_accessor :user
      
      def handle
        batch_id = runq.database[:batches] << {
          :scenario_id    => scenario_id,
          :scenario_xml   => scenario_xml,
          :name           => name,
          :n_runs         => n_runs,
          :mode           => mode,
          :engine         => engine,
          :b_time         => b_time,
          :duration       => duration,
          :control        => control,
          :qcontrol       => qcontrol,
          :events         => events,
          :group          => group,
          :user           => user,
          
          :start_time     => Time.now,
          :execution_time => nil,
          :n_complete     => 0
        }
        respond_ok("batch started",
          "batch_id" => batch_id
        )

        run_ids = n_runs.times.map do |i|
          runq.database[:runs] << {
            :batch_id     => batch_id,
            :worker_id    => nil,
            :frac_complete => 0
          }
          ## how else do runs differ
        end
        
        run_ids.each do |run_id|
          break unless runq.dispatch_run run_id
        end
      end
    end
    
    # For a given user, get active batches.
    class UserStatus < Request
      attr_accessor :user_id
      
      def handle
        batches = runq.database[:batches].where(:user => user_id).all
        respond_ok "got user #{user_id} status", "batches" => batches
      end
    end
    
    # For a given batch, get all runs (waiting, running, and finished).
    class BatchStatus < Request
      attr_accessor :batch_id
      
      def handle
        batch = runq.database[:batches].where(:id => batch_id).first
        runs = runq.database[:runs].where(:batch_id => batch_id).all
        respond_ok "got batch #{batch_id} status",
          "batch" => batch,
          "runs" => runs
      end
    end
    
    # Return list of all known batches.
    class BatchList < Request
      def handle
        batches = runq.database[:batches].all
        respond_ok "got batch list", "batches" => batches
      end
    end
    
    # Return list of all known workers, adding the :connected key to
    # each one, depending on whether we have a socket to it.
    class WorkerList < Request
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
    
    # For a given worker, get run and cpu stats.
    class WorkerStatus < Request
      ### TODO
    end
    
    # For a given run, get status.
    class RunStatus < Request
      ### TODO
    end
  end
end
