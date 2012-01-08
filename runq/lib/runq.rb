# This is the main file for the daemon that manages the queue of
# run requests and the queue of workers ready to execute runs.
#
# The daemon is run from the rakefile with 'rake start'. See 'rake --tasks'
# for details.

require 'logger'
require 'fileutils'
require 'timeout'
require 'thread'

require 'simx/mtcp'
require 'runq/db'
require 'runq/handlers/from-worker'
require 'runq/handlers/from-user'

require 'sequel'
require 'nokogiri'

require 'aws/s3'
require 'digest/md5'

require 'mime/types'

require 'runq/redmine-callbacks'

# We want to log the IP address of connected peers, but don't need full
# domain info (which may be useless anyway if peer is behind firewall or dhcp).
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

    def log
      @log ||= Logger.new(@log_file || $stderr, "weekly")
    end
    
    def database
      @database ||= begin
        FileUtils.mkdir_p DATA_DIR
        Database.new(DB_FILE, :timeout => 10_000, :log => log)
      end
    end

    def apiweb_db
      @apiweb_db ||= begin
        db = Sequel.connect ENV['APIWEB_DB_URL']
        log.info "Using aurora model database #{db.inspect}"
        
        require 'db/schema'
        Aurora.create_tables? db
        ## if network is not accessible, hangs here and INT fails
        ## how to time out?
        
        require 'db/model/aurora'
        require 'db/export/scenario'
        db
      end
      @apiweb_db
    end

    def ext_for_mime_type mime_type
      type = MIME::Types[mime_type].first
      if type
        type.extensions.first # this seems to be right for pdf, ppt, xls
      end
    end
    
    # Queue for all incoming requests, both from workers and from users.
    def request_queue
      @request_queue ||= Queue.new
    end

    # Queue for operations which may take long enough that they should not
    # interrupt request processing
    def op_queue
      @op_queue ||= Queue.new
    end
    
    # Last known socket for a worker id; this is the only non-persistent
    # state of the runq process. It is a hash of worker_id => socket.
    def socket_for_worker
      @socket_for_worker ||= {}
    end
    
    def parse_argv argv
      @production = argv.delete("--production")
      
      @port = Integer(ENV["RUNQ_PORT"]) rescue nil
      if (i = argv.index("--port")) ## use argos for this
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
      log; apiweb_db; database; request_queue; socket_for_worker
        # prevent race cond before starting threads
      
      log.level = @log_level
      log.info "Starting"
      
      trap("TERM") do
        request_queue << nil # wake the request queue thread
        # don't need to wake other threads because only the request queue thread
        # actually touches persistent state or sends replies
      end

      # start anything that can start, in case runq quit earlier with
      # some runs that could start but didn't
      dispatch_all
      
      svr_thread = Thread.new do
        run_server_thread
      end
      svr_thread.abort_on_exception = true
      
      req_thread = Thread.new do
        run_request_queue_thread
      end

      deferrable_op_thread = Thread.new do
        run_deferrable_op_thread
      end
      
      ## better to use a thwait here?
      req_thread.join
      
    rescue Interrupt, SignalException
      log.info "#{self} exiting"
      exit
    rescue Exception => e
      log.error "Main thread: " + [e.inspect, *e.backtrace].join("\n  ")
      raise
    end

    def run_deferrable_op_thread
      while op = op_queue.pop
        op.call
      end
    rescue => e
      log.error "Deferrable op thread: " + [e.inspect, *e.backtrace].join("\n  ")
      sleep 1
      retry
    end
    
    def run_server_thread
      MTCP::Server.open("0.0.0.0", @port) do |svr|
        log.info "Listening on #{svr.addr[2]}:#{svr.addr[1]}"
        loop do
          sock = svr.accept
          log.info "Connected to #{sock.peeraddr.inspect}"
          th = Thread.new(sock) do |s|
            run_recv_thread s
          end
          th.abort_on_exception = true
        end
      end
    rescue => e
      log.error "Server thread: " + [e.inspect, *e.backtrace].join("\n  ")
      sleep 1
      retry
    end
    
    # Manages incoming requests from one client: a worker or a web service.
    def run_recv_thread sock
      while msg_str = sock.recv_message
        req = YAML.load(msg_str)
        log.info "Got request from #{sock.peeraddr.inspect}"
        log.debug "request.inspect = #{req.inspect}"
        req.sock = sock
        req.runq = self
        request_queue << req
      end
      log.info "Receiver thread terminating: YAML stream closed"
    rescue MTCP::Error => e
      log.warn "Bad header from peer (#{e.message}), closing connection."
      sock.close
    rescue => e
      log.error "Receiver thread: " + [e.inspect, *e.backtrace].join("\n  ")
      sock.close
    end

    # This thread is the only one allowed to access the database.
    # nil request means stop thread
    def run_request_queue_thread
      while req = request_queue.pop
        handle_request req
      end
      log.info "Request queue thread terminating"
    rescue => e
      log.error "Request queue thread: " + [e, *e.backtrace].join("\n  ")
      sleep 1
      retry
    end
    
    def handle_request req
      if not req.wait or req.wait == 0 or req.wait_succeeded?
        handle_request_now req
        check_deferred req
      else
        defer_request req
      end
    end
    
    def handle_request_now req
      Timeout.timeout REQUEST_TIMEOUT do
        req.handle
      end
      
    rescue *NETWORK_ERRORS => e
      log.info "Client disconnected: (#{e.message}) " +
        "before handling request #{req} from #{req.sock.peeraddr.inspect}"
        
    rescue Timeout::Error
      log.warn "Timed out while handling request #{req} from " +
        req.sock.peeraddr.inspect
    end
    
    def deferred_requests
      @deferred_requests ||= []
    end
    
    def defer_request req
      deferred_requests.push [req, Time.now + [req.wait, 60].min]
    end
    
    # If this req changes the state that some deferred request is waiting for,
    # check if we can handle the deferred request.
    def check_deferred completed_req
      todo = deferred_requests
      @deferred_requests = []
      todo.each do |dreq, time|
        if dreq.wait_succeeded?
          ## probably could narrow this (check batch_id, check completed_req)
          handle_request_now dreq
        elsif Time.now < time
          deferred_requests.push [dreq, time]
        end
      end
    end
    
    # +req+ is WorkerReady; returns worker id
    def add_worker req
      ## need some basic security here
      
      worker_id = database[:workers].insert({
        :host         => req.host,
        :ipaddr       => req.sock.peeraddr[3],
        :pid          => req.pid,
        :group        => req.group,
        :user         => req.user,
        :engine       => req.engine,
        :cost         => req.cost,
        :speed        => req.speed,
        :priority     => req.priority,
        :run_id       => nil,  # none yet, hence worker is ready
        :last_contact => Time.now
      })
      ## check if uniq host/pid
      ## check if valid group/user
      
      socket_for_worker[worker_id] = req.sock
      log.info "Added worker #{worker_id}"
      
      return worker_id
    end
    
    # +req+ is WorkerReconnect
    def reconnect_worker req
      worker_id = req.worker_id
      socket_for_worker[worker_id] = req.sock
      
      workers = database[:workers].where(:id => worker_id)
      case workers.count
      when 0
        # This case is possible if runq was stopped and its database was
        # cleared.
        add_worker req
      when 1
        workers.update(
          :last_contact => Time.now,
          :ipaddr       => req.sock.peeraddr[3] # in case of dhcp, for example
        )
        log.info "Reconnected worker #{worker_id}"
      else
        log.error "Too many workers with id=#{worker_id}"
      end
    end
    
    # +req+ is WorkerUpdate
    def update_worker req
      worker_id = req.worker_id
      workers = database[:workers].where(:id => worker_id)
      worker = workers.first

      workers.update(
        :last_contact => Time.now
      )

      run_id = worker[:run_id] ### handle worker == nil
      
      database[:runs].where(:id => run_id).update(
        :frac_complete  => req.frac_complete
        ## store progress as well?
      )
      run = database[:runs].where(:id => run_id).first

      batch = database[:batches].where(:id => run[:batch_id]).first

      log.debug "Run update callback = #{run[:update_callback]}"
      if run[:update_callback]
        self.send run[:update_callback], {
          :worker => worker,
          :batch_param => YAML.load(batch[:param]),
          :run => run,
          :req => req
        }
      end
    end

    # +req+ is WorkerNeedsAssistance
    def assist_worker req
      allowed_methods = [:scenario_export]
      if allowed_methods.include?(req.runq_assist_method)
        op_queue << Proc.new do
          send(req.runq_assist_method, req)
        end
      end
    end

    def scenario_export req
      params = req.runq_assist_params
      match = /@scenario\((\d+)\)/.match(params.first)
      scenario_id = match[1] 
      log.debug "Exporting scenario #{scenario_id} for simulation db=#{apiweb_db}"
      scenario_url = Aurora::Scenario.export_and_store_on_s3(scenario_id, apiweb_db)
      log.debug "scenario URL: #{scenario_url}"

      info_request = Request::RunqProvideInformation.new
      info_request.sock = socket_for_worker[req.worker_id]
      info_request.worker_id = req.worker_id
      info_request.info_type = :param_update
      info_request.info_value = { :scenario_url => scenario_url }
      request_queue << info_request
      log.debug "queueing info request #{info_request.inspect}"
    end
    
    # +req+ is WorkerFinishedRun
    def finished_worker req
      worker_id = req.worker_id
      data = req.data
      workers = database[:workers].where(:id => worker_id)
      worker = workers.first
      
      workers.update(
        :last_contact => Time.now,
        :run_id => nil
      )
      
      runs = database[:runs].where(:id => worker[:run_id])
      runs.update(
        :frac_complete => 1.0,
        :data => data.to_yaml
        # leave the worker_id intact as record of who did the run
        # and to signify that the run is not waiting to start
      )
      run = runs.first
      
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

      if run[:finish_callback]
        self.send run[:finish_callback], {
          :worker => worker,
          :batch_param => YAML.load(batch[:param]),
          :n_complete => new_n_complete,
          :n_runs => n_runs,
          :run => run,
          :req => req
        }
      end

      log.info "Finished run by worker #{worker_id}; " +
        "#{new_n_complete} of #{n_runs} runs done in batch #{batch_id}"
      log.debug "Run result = #{data.inspect}"
    end
    
    # +req+ is WorkerAbortedRun
    def aborted_worker req
      worker_id = req.worker_id
      workers = database[:workers].where(:id => worker_id)
      worker = workers.first
      
      workers.update(
        :last_contact => Time.now,
        :run_id => nil
      )
      
      runs = database[:runs].where(:id => worker[:run_id])
      #runs.update(
        # leave the frac_complete intact of a record of last update
        #
        # leave the worker_id intact as record of who did the run
        # and to signify that the run is not waiting to start
      #)
      run = runs.first
      
      batches = database[:batches].where(:id => run[:batch_id])
      batch = batches.first
      batch_id = batch[:id]
      new_n_complete = batch[:n_complete] + 1 ## ?
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
      
      ## what else do we need to do?
      ## - put abort message in db, so runweb can get it?
      ## - flag in batch that indicates there were aborted runs?

      log.info "Aborted run by worker #{worker_id}; " +
        "#{new_n_complete} of #{n_runs} runs done in batch #{batch_id}\n"
    end
    
    # +req+ is WorkerFailedRun
    def failed_worker req
      worker_id = req.worker_id
      message = req.message
      workers = database[:workers].where(:id => worker_id)
      worker = workers.first
      
      workers.update(
        :last_contact => Time.now,
        :run_id => nil
      )
      
      runs = database[:runs].where(:id => worker[:run_id])
      runs.update(
        # leave the frac_complete intact of a record of last update
        #
        # leave the worker_id intact as record of who did the run
        # and to signify that the run is not waiting to start
        :data => message
      )
      run = runs.first
      
      batches = database[:batches].where(:id => run[:batch_id])
      batch = batches.first
      batch_id = batch[:id]
      new_n_complete = batch[:n_complete] + 1 ## ?
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
      
      ## what else do we need to do?
      ## - put failure message in db, so runweb can get it?
      ## - flag in batch that indicates there were failures?

      log.info "Failed run by worker #{worker_id}; " +
        "#{new_n_complete} of #{n_runs} runs done in batch #{batch_id}\n" +
        message
    end
    
    # +req+ is WorkerStoppedRun
    def stopped_worker req
      worker_id = req.worker_id
      workers = database[:workers].where(:id => worker_id)
      worker = workers.first
      
      workers.update(
        :last_contact => Time.now,
        :run_id => nil
      )
      
      runs = database[:runs].where(:id => worker[:run_id])
      runs.update(
        :frac_complete  => 0,
        :worker_id      => nil
      )
      
      log.info "Stopped run by worker #{worker_id}"
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
        return false
      end
      
      if worker[:run_id]
        log.error "Worker #{worker_id} already has a run"
        return false
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
        return true
      else
        log.info "No matching runs for worker #{worker_id}."
        return false
      end
      
    rescue WorkerDisconnected => e
      log.warn "Worker #{e.worker_id} disconnected: #{e}"
      sock = socket_for_worker.delete e.worker_id
      sock.close if sock and not sock.closed?
      return false
    end
    
    # A run has been requested, so try to find a matching worker.
    # If no match, returns false. Returns immediately.
    def dispatch_run run_id
      run = database[:runs].where(:id => run_id).first
      
      # no race cond here because there is only one thread in db
      ready_workers = database[:workers].where(:run_id => nil).
        order_by(:cost, :speed.desc, :priority.desc)

      matching_workers = ready_workers.all.select do |worker|
        have_match(worker, run)
      end
      
      worker = matching_workers.first ## fairer order?
      if worker
        send_run_to_worker run, worker
        return true
      else
        log.info "No matching workers for run #{run_id}."
        return false
      end
      
      purge_workers
      
    rescue WorkerDisconnected => e
      log.warn "Worker #{e.worker_id} disconnected: #{e}"
      sock = socket_for_worker.delete e.worker_id
      sock.close if sock and not sock.closed?
      log.info "Retrying dispatch_run"
      retry
    end

    def have_match worker, run
      log.debug {
        "checking worker #{worker.inspect} for match with run #{run.inspect}"
      }
      
      ## may need more sophisticated logic here
      ## should we push logic into the sequel query?
      
      s = socket_for_worker[worker[:id]]
      unless s && !s.closed?
        log.debug {"worker #{worker[:id]} has disconnected"}
        return false
      end
      
      batch = database[:batches].where(:id => run[:batch_id]).first
      
      unless batch
        log.debug "missing batch -- foreign key constraint failed"
        return false
      end
      
      unless /^(?:#{worker[:engine]})$/ === batch[:engine]
        log.debug {
          "engine mismatch: worker accepts #{worker[:engine].inspect} but " +
          "batch requests #{batch[:engine].inspect}"
        }
        return false
      end
      
      if worker[:group]
        unless /^(?:#{worker[:group]})$/ === batch[:group]
          log.debug {
            "group mismatch: worker accepts #{worker[:group].inspect} but " +
            "batch requests #{batch[:group].inspect}"
          }
          return false
        end
      end

      if worker[:user]
        unless /^(?:#{worker[:user]})$/ === batch[:user]
          log.debug {
            "user mismatch: worker accepts #{worker[:user].inspect} but " +
            "batch requests #{batch[:user].inspect}"
          }
          return false
        end
      end
      
      log.debug {
        "worker #{worker.inspect} matches run #{run.inspect}"
      }

      return true
    end
    
    def send_run_to_worker run, worker
      run_id = run[:id]
      batch_id = run[:batch_id]
      batch_index = run[:batch_index]
      batch = database[:batches].where(:id => batch_id).first
      
      if apiweb_db.table_exists?(:simulation_batches)
        frontend_batches = apiweb_db[:simulation_batches]
      else
        # in case simx is running in standalone mode
        frontend_batches = nil
      end
      
      worker_id = worker[:id]
      param = YAML.load(batch[:param]) ## cache this per batch
      
      log.info "sending run #{run_id} from batch #{batch_id} to " +
        "worker #{worker_id}"
      log.debug "run params: #{param.inspect}"
      
      msg = Request::RunqAssignRun.new(
        :param        => param,
        :engine       => batch[:engine],
        :batch_index  => batch_index
      )
     
      begin
        sock = socket_for_worker[worker_id]
        sock.send_message msg.to_yaml
      rescue *NETWORK_ERRORS => e
        wdex = WorkerDisconnected.new
        wdex.worker_id = worker_id
        raise wdex,
          "Failed to send run #{run_id} to worker #{worker_id}: #{e.inspect}"
      end

      # If the transmission succeeded, mark the run and worker as belonging to
      # each other.
      database[:runs].where(:id => run_id).update(:worker_id => worker_id)
      database[:workers].where(:id => worker_id).update(:run_id => run_id)

      if batch[:engine] == 'simulator'
        batch_param = YAML.load(batch[:param])
        simulation_batch_id = batch_param[:redmine_simulation_batch_id]
        if frontend_batches
          frontend_batches.where(:id => simulation_batch_id).
            update(:number_of_runs => batch[:n_runs], :start_time => Time.now)
        end
      end

      add_redmine_callbacks run_id, batch[:engine], param

      log.info "Dispatched run #{run_id}, " +
        "index #{batch_index} in batch #{batch_id} " +
        "to worker #{worker_id}"
      log.debug "message:\n#{msg.to_yaml}"
      
      return true
    end
    
    # Call this periodically to delete worker records that do not have
    # an open socket. Does not handle the case of stalled worker with
    # a run that never finishes.
    def purge_workers
      t = Time.now - 24*60*60
      ws = database[:workers].
            where(:run_id => nil).
            where {last_contact < t}.
            all.select do |w|
              s = socket_for_worker[w[:id]]
              !s or s.closed?
            end
      
      ws.each do |w|
        log.info "purging worker #{w.inspect}"
        socket_for_worker.delete w[:id]
      end
    end

    ### how to periodically purge old records from db?
    ### and check if batch or run is stalled? or sock is dead?
    ### how to restart run if worker went away?
    ### maybe we can use the update_period (+n) as the period to check?
  end
end

if __FILE__ == $0
  Runq.parse_argv ARGV
  Runq.run
end
