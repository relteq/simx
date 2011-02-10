# This is the main file for the daemon that manages the queue of
# run requests and the queue of workers ready to execute runs.
#
# The daemon is run from the rakefile with 'rake start'.

require 'logger'
require 'fileutils'
require 'timeout'
require 'thread'

require 'simx/mtcp'
require 'runq/db'
require 'runq/request'

# We want to log the IP address of connected peers, but don't need full
# domain info.
## This should probably be set to false in production.
Socket.do_not_reverse_lookup = true

module Runq
  # seconds we wait for any request to finish
  REQUEST_TIMEOUT = 10
  
  NETWORK_ERRORS = [Errno::ECONNRESET, Errno::ECONNABORTED,
    Errno::ECONNREFUSED,
    Errno::EPIPE, IOError, Errno::ETIMEDOUT]
  
  class WorkerDisconnected < StandardError
    attr_accessor :worker_id
  end
  
  class << self
    attr_reader :production

    # last known socket for a worker id; this is the only non-persistent
    # state of the runq process
    attr_reader :socket_for_worker # hash { worker_id => socket }

    def log
      @log ||= Logger.new(@log_file || $stderr, "weekly")
    end
    
    def database
      @database ||= begin
        FileUtils.mkdir_p DATA_DIR
        Database.new(DB_FILE, :timeout => 10_000, :log => log)
      end
    end
    
    def parse_argv argv
      @production = argv.delete("--production")
      
      @port = Integer(ENV["RUNQ_PORT"])
      if (i = argv.index("--port"))
        _, @port = argv.slice!(i, 2)
        @port = Integer(@port)
      end

      @log_level = Logger::DEBUG
      if (i = argv.index("--log-level"))
        _, level = argv.slice!(i, 2)
        level = level.upcase
        if Logger::Severity.constants.include?(level)
          @log_level = Logger::Severity.const_get(level)
        end
      end

      if (i = argv.index("--log-file"))
        _, @log_file = argv.slice!(i, 2)
      end
    end
    
    def run
      @socket_for_worker = {}
      @request_queue = Queue.new
      
      log.level = @log_level
      log.info "Starting"
      
      trap("TERM") do
        @request_queue << nil # wake the request queue thread
        # don't need to wake other threads because only the request queue thread
        # actually touches persistent state or sends replies
      end

      svr_thread = Thread.new do
        run_server_thread
      end
      
      req_thread = Thread.new do
        run_request_queue_thread
      end
      
      req_thread.join
      
    rescue Interrupt, SignalException
      log.info "#{self} exiting"
      exit
    rescue => e
      log.error "Main thread: " + [e.inspect, *e.backtrace].join("\n  ")
      raise
    rescue Exception => e
      log.warn e
      raise
    end
    
    def run_server_thread
      MTCP::Server.open("0.0.0.0", @port) do |svr|
        log.info "Listening on #{svr.addr[2]}:#{svr.addr[1]}"
        loop do
          sock = svr.accept
          log.info "Connected to #{sock.peeraddr.inspect}"
          Thread.new(sock) do |s|
            run_request_thread s
          end
        end
      end
    rescue => e
      log.error "Server thread: " + [e.inspect, *e.backtrace].join("\n  ")
      retry
    end
    
    # Manages requests from workers and web services
    def run_request_thread sock
      dispatch_all
      
      while msg_str = sock.recv_message
        req = YAML.load(msg_str)
        log.info "Got request from #{sock.peeraddr.inspect}"
        req.sock = sock
        req.runq = self
        @request_queue << req
      end
      log.info "Request thread terminating: YAML stream closed"
    rescue => e
      log.error "Request thread: " + [e.inspect, *e.backtrace].join("\n  ")
    end

    # This thread is the only one allowed to access the database.
    # nil request means stop thread
    def run_request_queue_thread
      while req = @request_queue.pop
        handle_request req
      end
      log.info "Request queue thread terminating"
    rescue => e
      log.error "Request queue thread: " + [e, *e.backtrace].join("\n  ")
      retry
    end
    
    def handle_request req
      Timeout.timeout REQUEST_TIMEOUT do
        req.handle
      end
    rescue WorkerDisconnected => e
      log.warn "Request queue thread for worker #{e.worker_id}: #{e}"
      sock = socket_for_worker.delete e.worker_id
      sock.close if sock and not sock.closed?
    rescue Timeout::Error
      log.warn "Timed out while handling request #{req} from " +
        req.sock.peeraddr.inspect
    end
    
    # +req+ is WorkerReady; returns worker id
    def add_worker req
      worker_id = database[:workers] << {
        :host     => req.host,
        :pid      => req.pid,
        :group    => req.group,
        :user     => req.user,
        :engine   => req.engine,
        :cost     => req.cost,
        :run_id   => nil  # none yet, hence worker is ready
      }
      ## check if uniq host/pid
      ## check if valid group/user
      
      socket_for_worker[worker_id] = req.sock
      log.info "Added worker #{worker_id}"
      
      return worker_id
    end
    
    # +req+ is WorkerReconnect
    def reconnect_worker req
      socket_for_worker[req.worker_id] = req.sock
    end
    
    # +req+ is WorkerUpdate
    def update_worker req
      worker_id = req.worker_id
      socket_for_worker[worker_id] = req.sock # might have changed

      workers = database[:workers].where(:id => worker_id)
      worker = workers.first

      database[:runs].where(:id => worker[:run_id]).update(
        :frac_complete => req.frac_complete
      )
      log.info "Updated worker #{worker_id}, frac = #{req.frac_complete}"
    end
    
    # +req+ is WorkerFinishedRun
    def finished_worker(req)
      worker_id = req.worker_id
      socket_for_worker[worker_id] = req.sock # might have changed
      
      workers = database[:workers].where(:id => worker_id)
      worker = workers.first
      
      runs = database[:runs].where(:id => worker[:run_id])
      runs.update(
        :frac_complete => 1.0
        # leave the worker_id intact as record of who did the run
        # and to signify that the run is not waiting to start
      )
      run = runs.first
      
      workers.update(
        :run_id => nil
      )
      
      batches = database[:batches].where(:id => run[:batch_id])
      batch = batches.first
      batch_id = batch[:id]
      new_n_complete = batch[:n_complete] + 1
      n_runs = batch[:n_runs]
      if new_n_complete == n_runs
        batches.update(
          :n_complete => new_n_complete,
          :execution_time  => Time.now - batch[:start_time]
        )
      else
        batches.update(
          :n_complete => new_n_complete
        )
      end

      log.info "Finished run by worker #{worker_id}; " +
        "#{new_n_complete} of #{n_runs} runs done in batch #{batch_id}"
    end
    
    # Look for all runs and workers that can be matched, and set them to work.
    # Normally, this is only called when the daemon starts.
    def dispatch_all
      waiting_runs = database[:runs].where(:worker_id => nil)
      waiting_runs.each do |run|
        dispatch_run run[:id]
      end
    end
    
    # A worker has become available, so try to find a matching run.
    # If no match, return false. Returns immediately.
    def dispatch_to_worker worker_id
      worker = database[:workers].where(:id => worker_id).first
      
      if not worker
        log.error "Worker #{worker_id} does not exist. Perhaps db was cleared?"
        return
      end
      
      if worker[:run_id]
        log.warn "Worker #{worker_id} already has a run"
        return
      end
      
      # no race cond here because there is only one thread in db
      waiting_runs = database[:runs].where(:worker_id => nil)
      
      matching_runs = waiting_runs.all.select do |run|
        have_match(worker, run)
        ## optimization: need to check only one run per batch
      end
      
      run = matching_runs.first ## fairer order based on timestamp?
      if run
        send_run_to_worker run, worker
      else
        log.info "No matching runs for worker #{worker_id}."
        false
      end
    end
    
    # A run has been requested, so try to find a matching worker.
    # If no match, returns false. Returns immediately.
    def dispatch_run run_id
      run = database[:runs].where(:id => run_id).first
      
      # no race cond here because there is only one thread in db
      ready_workers = database[:workers].where(:run_id => nil).order_by(:cost)

      matching_workers = ready_workers.all.select do |worker|
        have_match(worker, run)
      end
      
      worker = matching_workers.first ## fairer order?
      if worker
        send_run_to_worker run, worker
      else
        log.info "No matching workers for run #{run_id}."
        false
      end
    end

    def have_match worker, run
      ## may need more sophisticated logic here
      ## should we push logic into the sequel query?
      s = socket_for_worker[worker[:id]]
      batch = database[:batches].where(:id => run[:batch_id]).first

      batch &&
      s && !s.closed? &&
      (batch[:engine] == worker[:engine]) &&
      (batch[:group] == worker[:group]) &&
      (!worker[:user] || batch[:user] == worker[:user])
    end
    
    def send_run_to_worker run, worker
      run_id = run[:id]
      batch_id = run[:batch_id]
      batch = database[:batches].where(:id => batch_id).first
      worker_id = worker[:id]
      
      ### use a class
      msg = {
        "status"  => "ok",
        "message" => "sending scenario"
      }
      
      if batch[:scenario_id]
        msg["scenario_xml"] = nil ### TODO: export from database
      elsif batch[:scenario_xml]
        msg["scenario_xml"] = batch[:scenario_xml]
      else
        raise "Batch #{batch_id} has neither scenario_id nor scenario_xml"
      end

      begin
        sock = socket_for_worker[worker_id]
        sock.send_message msg.to_yaml
      rescue *NETWORK_ERRORS => ex
        wdex = WorkerDisconnected.new
        wdex.worker_id = worker_id
        raise wdex, "Failed to send run #{run_id} to worker #{worker_id}: #{ex.inspect}"
      end

      database[:runs].where(:id => run_id).update(
        :worker_id => worker_id
      )
      database[:workers].where(:id => worker_id).update(
        :run_id => run_id
      )

      log.info "Dispatched #{run_id} in batch #{batch_id} " +
        "to worker #{worker_id}"
      
      return true
    end

    ### how to periodically purge old records from db?
    ### and check if batch or run is stalled? or sock is dead?
    ### periodically delete worker records that do not have a corr socket
  end
end

if __FILE__ == $0
  Runq.parse_argv ARGV
  Runq.run
end
