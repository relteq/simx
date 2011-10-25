require 'logger'
require 'thread'
require 'thwait'
require 'yaml'

require 'simx/mtcp'
require 'runq/request'

# Computation worker processes. Controls a sequence of Run instances, one at a
# time. Each Run manages the state of an individual run of the computation.
# A run is started in response to a request from the controlling runq.
#
# A Worker does not manage daemonization, restarting, process monitoring etc.,
# (except possibly for monitoring an external process doing the actual
# computation) so, in the context of a server, it should usually be run as a
# child of a process which does those things. See the WorkerManager.
#
# Alternately, a worker can run ad hoc from any host (e.g. a desktop PC).
#
class Worker
  # Opts specified in local worker config (not in message from runq).
  attr_reader :opts
  
  # Subclass of Run::Base which this worker instantiates.
  attr_reader :run_class
  
  # Host on which runq server is listening.
  attr_reader :runq_host
  
  # Port on which runq server is listening.
  attr_reader :runq_port
  
  # Host on which apiweb server is listening.
  attr_reader :apiweb_host
  
  # Port on which apiweb server is listening.
  attr_reader :apiweb_port
  
  # Worker accepts runs from this group (nil means any).
  attr_reader :group
  
  # Worker accepts runs from this user (nil means any).
  attr_reader :user
  
  # Worker accepts runs requested for this engine.
  attr_reader :engine
  
  # Local config for this engine.
  attr_reader :engine_opts
  
  # Unit-less assessment of the cost of this worker.
  attr_reader :cost
  
  # Unit-less assessment of the speed of this worker.
  attr_reader :speed
  
  # Tie-breaker for when multiple workers available, e.g. on two hosts.
  attr_reader :priority
  
  # Seconds between retries.
  attr_reader :retry_delay
  
  # Device (file descriptor or filename) for logging.
  attr_reader :logdev

  # Instance of Logger
  attr_reader :log
  
  # Queue of events to be handled by main loop thread.
  attr_reader :event_queue
  
  # Instantiated per run, keeps track of run status.
  attr_reader :current_run
  
  # Assigned on first contact with runq server.
  # Persists across all tcp sessions.
  attr_reader :worker_id
  
  DEFAULT_COST        = 0
  DEFAULT_SPEED       = 1
  DEFAULT_PRIORITY    = 1
  DEFAULT_RETRY_DELAY = 10
  
  def initialize run_class, opts
    argerr = ArgumentError

    unless opts.kind_of? Hash
      raise argerr, "opts must be a hash, not #{opts.class}"
    end
    @opts = opts
    
    @run_class = run_class or raise argerr, "missing run_class"
    
    @runq_host    = opts["runq_host"]    or raise argerr, "missing :runq_host"
    @runq_port    = opts["runq_port"]    or raise argerr, "missing :runq_port"
    @apiweb_host  = opts["apiweb_host"]  or raise argerr, "missing :apiweb_host"
    @apiweb_port  = opts["apiweb_port"]  or raise argerr, "missing :apiweb_port"
    @group        = opts["group"]
    @user         = opts["user"]
    @engine       = opts["engine"]       or raise argerr, "missing :engine"
    @engine_opts  = opts["engine_opts"]
    @cost         = opts["cost"]         || DEFAULT_COST
    @speed        = opts["speed"]        || DEFAULT_SPEED
    @priority     = opts["priority"]     || DEFAULT_PRIORITY
    @retry_delay  = opts["retry_delay"]  || DEFAULT_RETRY_DELAY
    @logdev       = opts["logdev"]       || $stderr
    
    @log = Logger.new(logdev, "weekly")
    @event_queue = Queue.new
    @mutex = Mutex.new
    @thread_wait = ThreadsWait.new
    @current_run = nil
    @worker_id = nil
  end
  
  # Returns true if socket needed to be opened, false otherwise.
  def open_runq_socket
    @mutex.synchronize do
      if not @runq_socket or @runq_socket.closed?
        @runq_socket = MTCP::Socket.open(runq_host, runq_port)
        true
      else
        false
      end
    end
  end

  def close_runq_socket
    @mutex.synchronize do
      @runq_socket.close if @runq_socket and !@runq_socket.closed?
      @runq_socket = nil
    end
  end
  
  # Open socket if needed, and if so, tells the runq that worker is reconnecting
  # with a previously registererd ID.
  def connect_runq_socket
    if open_runq_socket
      runq_send_reconnect if worker_id
      addr = @runq_socket.peeraddr
      log.info "Connected to #{addr[2]}:#{addr[1]}"
    end
  end
  
  # Try once to get a socket that is connected to the runq server.
  # On network failure, return nil.
  # On success, if block given, yield the socket and return block value.
  # Otherwise, return the socket.
  def runq_socket?
    begin
      connect_runq_socket
    rescue SystemCallError => e
      log.warn e.message
      close_runq_socket
    end

    if block_given? and @runq_socket
      yield @runq_socket
    else
      @runq_socket
    end
  end
  
  # Keep trying to get a socket to runq. Does not fail or yield.
  def runq_socket!
    connect_runq_socket
    @runq_socket
    
  rescue SystemCallError => e
    log.warn e.message
    log.info  "Sleeping for #{retry_delay} seconds"
    sleep retry_delay
    log.info "Retrying..."
    retry
  end
  
  # Try to send once, and ignore network failure. Return true on success.
  def runq_send? obj
    runq_socket? do |sock|
      str = obj.to_yaml
      begin
        sock.send_message str
        log.info "Sent a #{obj.class} to runq"
        log.debug "Sent:\n#{str}"
        true
      rescue SystemCallError => e
        close_runq_socket
        log.warn e.message
        false
      end
    end
  end
  
  # Keep trying to send.
  def runq_send! obj
    str = obj.to_yaml
    begin
      runq_socket!.send_message str
      log.info "Sent a #{obj.class} to runq"
      log.debug "Sent:\n#{str}"
    rescue SystemCallError => e
      close_runq_socket
      log.warn e.message
      retry
    end
  end
  
  # Try once to receive a message. If socket can't be connected or
  # there is no incoming message, return false. Otherwise return message.
  def runq_recv?
    runq_socket? do |sock|
      have_message = IO.select([sock], nil, nil, 0) rescue nil
      return false unless have_message

      begin
        str = sock.recv_message
      rescue SystemCallError => e
        close_runq_socket
        log.warn e.message
        false
      else
        if str
          log.debug "Received:\n#{str}"
          obj = YAML.load(str)
          log.info "Received a #{obj.class} from runq"
          obj
        else
          log.info "Socket closed by runq."
          close_runq_socket
          false
        end
      end
    end
  end
  
  # Keep trying to receive a message. Returns false only if runq closed socket.
  def runq_recv!
    str = runq_socket!.recv_message
    if str
      log.debug "Received:\n#{str}"
      obj = YAML.load(str)
      log.info "Received a #{obj.class} from runq"
      obj
    else
      log.info "Socket closed by runq."
      close_runq_socket
      false
    end

  rescue SystemCallError => e
    close_runq_socket
    log.warn e.message
    retry
  end
  
  def runq_send_ready
    runq_send! Runq::Request::WorkerReady.new(
      :host     => `hostname`.strip,
      :pid      => $$,
      :group    => group,
      :user     => user,
      :engine   => engine,
      :cost     => cost,
      :speed    => speed,
      :priority => priority
    )
  end
  
  def runq_send_reconnect
    runq_send! Runq::Request::WorkerReconnect.new(
      :worker_id      => worker_id,
      
      # usually redundant, but see note in request.rb.
      :host     => `hostname`.strip,
      :pid      => $$,
      :group    => group,
      :user     => user,
      :engine   => engine,
      :cost     => cost,
      :speed    => speed,
      :priority => priority
    )
  end
  
  def runq_send_update message = nil
    runq_send? Runq::Request::WorkerUpdate.new(
      :worker_id      => worker_id,
      :progress       => current_run ? current_run.progress : "", ## ?
      :message        => message
    )
  end
  
  def runq_send_finished data
    runq_send! Runq::Request::WorkerFinishedRun.new(
      :worker_id      => worker_id,
      :data           => data
    )
  end
  
  def runq_send_aborted
    runq_send! Runq::Request::WorkerAbortedRun.new(
      :worker_id      => worker_id
    )
  end
  
  def runq_send_failed message
    runq_send! Runq::Request::WorkerFailedRun.new(
      :worker_id      => worker_id,
      :message        => message
    )
  end
  
  def runq_send_stopped
    runq_send? Runq::Request::WorkerStoppedRun.new(
      :worker_id      => worker_id
    )
  end

  def runq_send_need_assistance(event)
    runq_send? Runq::Request::WorkerNeedsAssistance.new(
      :worker_id => worker_id,
      :runq_assist_method => event.operation_needed,
      :runq_assist_params => event.operation_params
    )
  end
  
  def initial_handshake
    runq_send_ready
    resp = runq_recv!
    
    case resp
    when Runq::Request::RunqAcceptWorker
      @worker_id = resp.worker_id
    else
      log.warn "Unexpected request during initial_handshake: #{resp.inspect}."
    end
    
    unless @worker_id
      raise "Could not connect to runq and obtain a worker id."
    end
  end
  
  def start_event_loop
    Thread.new do
      loop do
        handle_event event_queue.pop
      end
    end
  end
  
  def handle_event event
    case event
    when Runq::Request
      handle_runq_request event
    when Run::Event
      handle_run_event event
    else
      log.error "Unrecognized event: #{event.inspect}"
    end
  end
  
  def handle_runq_request req
    case req
    when Runq::Request::RunqAssignRun
      if current_run
        log.error "Requested to start a new run before current run done."
        return
      else
        start_run req.param, req.engine, req.batch_index
      end
      
    when Runq::Request::RunqGetStatus
      if r=current_run
        runq_send_update r.status
      end
    
    when Runq::Request::RunqAbortRun
      if r=current_run
        r.abort
      end

    when Runq::Request::RunqProvideInformation
      if r=current_run
        r.update_with_info req 
      end
    
    else
      log.warn "Unexpected runq request: #{req.inspect}."
    end
  end
  
  def handle_run_event event
    case event
    when Run::Event::Finished
      @current_run = nil
      runq_send_finished event.data
    when Run::Event::Aborted
      @current_run = nil
      runq_send_aborted
    when Run::Event::Stopped
      @current_run = nil
      runq_send_stopped
      exit 0 # the worker is requested to stop, not just the run
    when Run::Event::Failed
      @current_run = nil
      runq_send_failed event.message
    when Run::Event::Update
      runq_send_update
    when Run::Event::Blocked
      runq_send_need_assistance event
    else
      log.warn "Unexpected run event: #{event.inspect}."
    end
  end
  
  def handle_error
    yield
  rescue SystemExit
  rescue Exception => e
    log.error [e.inspect, *e.backtrace].join("\n  ")
    raise
  end
  
  def start_runq_listener
    Thread.new do
      loop do
        req = runq_recv!
        if req
          event_queue << req
        else
          log.info "Server closed the message socket. Waiting again."
        end
      end
    end
  end
  
  # +engine+ is the requested engine, which should match the worker's engine
  def start_run param, engine, batch_index
    if current_run
      raise "Called start_run, but current_run is not nil."
    end
    
    @current_run = run_class.new(
      :event_queue    => event_queue,
      :log            => log,
      :param          => param,
      :batch_index    => batch_index,
      :apiweb_host    => apiweb_host,
      :apiweb_port    => apiweb_port,
      :engine         => engine,
      :engine_opts    => engine_opts
    )
    
    thread = @current_run.start
    @thread_wait.join_nowait thread
    thread
  end

  def execute
    trap "TERM" do
      if current_run
        current_run.stop
        # exit -- handled by queue handler
      else
        exit
      end
    end
    
    handle_error do
      initial_handshake
      @thread_wait.join_nowait start_runq_listener, start_event_loop
      @thread_wait.all_waits do |thread|
        thread.join
      end
    end
  end
end
