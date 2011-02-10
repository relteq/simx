require 'logger'

require 'simx/mtcp'
require 'runq/request'

## TODO:
##
## handle signals: INT and TERM

# Abstract base class for simulation/computation worker processes.
# Subclasses must implement #execute_one_run and #frac_complete.
#
# A Worker does not manage daemonization, restarting, process monitoring etc.,
# so, in the context of a server, it should usually be run as a child of
# a process which does those things.
#
# Alternately, a worker can run ad hoc from any host (e.g. a desktop PC).
#
class AbstractWorker
  # Host on which runq server is listening.
  attr_reader :runq_host
  
  # Port on which runq server is listening.
  attr_reader :runq_port
  
  # Worker accepts runs from this group.
  attr_reader :group
  
  # Worker accepts runs from this user.
  attr_reader :user
  
  # Matches requested engine of a run.
  attr_reader :engine
  
  # Unit-less assessment of the cost of this worker.
  attr_reader :cost
  
  # Seconds between retries.
  attr_reader :retry_delay
  
  # Device (e.g. file descriptor) for logging.
  attr_reader :logdev

  # Instance of Logger
  attr_reader :log
  
  # Assigned on first contact with runq server.
  # Persists across all tcp sessions.
  attr_reader :worker_id
  
  def initialize opts
    @runq_host    = opts[:runq_host]
    @runq_port    = opts[:runq_port]
    @group        = opts[:group]
    @user         = opts[:user]
    @engine       = opts[:engine]
    @cost         = opts[:cost]
    @retry_delay  = opts[:retry_delay]
    @logdev       = opts[:logdev]
    
    @log = Logger.new(logdev)
    
    @worker_id = nil
  end
  
  # Try once to get a socket that is connected to the runq server.
  # On network failure, return nil.
  # On success, if block given, yield and return block value.
  # Otherwise, return the socket.
  def runq_socket
    if not @runq_socket or @runq_socket.closed?
      begin
        @runq_socket = MTCP::Socket.open(runq_host, runq_port)
        runq_send_reconnect if worker_id
        addr = @runq_socket.peeraddr
        log.info "Connected to #{addr[2]}:#{addr[1]}"
      rescue SystemCallError => e
        log.warn e.message
        @runq_socket = nil
      end
    end

    if block_given? and @runq_socket
      yield @runq_socket
    else
      @runq_socket
    end
  end
  
  # Keep trying to get a socket to runq. Does not fail or yield.
  def runq_socket!
    if not @runq_socket or @runq_socket.closed?
      @runq_socket = MTCP::Socket.open(runq_host, runq_port)
      runq_send_reconnect if worker_id
      addr = @runq_socket.peeraddr
      log.info "Connected to #{addr[2]}:#{addr[1]}"
    end
    
    @runq_socket
    
  rescue SystemCallError => e
    log.warn e.message
    log.info  "Sleeping for #{retry_delay} seconds"
    sleep retry_delay
    log.info "Retrying..."
    retry
  end
  
  # Try to send once, and ignore network failure.
  def runq_send obj
    runq_socket do |sock|
      str = obj.to_yaml
      begin
        sock.send_message str
        log.debug "Sent:\n#{str}"
      rescue SystemCallError => e
        @runq_socket = nil
        log.warn e.message
        nil
      end
    end
  end
  
  # Keep trying to send.
  def runq_send! obj
    str = obj.to_yaml
    begin
      runq_socket!.send_message str
      log.debug "Sent:\n#{str}"
    rescue SystemCallError => e
      @runq_socket = nil
      log.warn e.message
      retry
    end
  end
  
  # Try once to receive a message. If socket can't be connected or
  # there is no incoming message, return nil.
  def runq_recv
    runq_socket do |sock|
      have_message = IO.select([sock], nil, nil, 0) rescue nil
      if have_message
        str =
          begin
            sock.recv_message
          rescue SystemCallError => e
            @runq_socket = nil
            log.warn e.message
            nil
          end
        
        if str
          log.debug "Received:\n#{str}"
          YAML.load(str)
        else
          @runq_socket.close
          @runq_socket = nil
          nil
        end
      end
    end
  end
  
  # Keep trying to receive a message.
  def runq_recv!
    str = runq_socket!.recv_message
    if str
      log.debug "Received:\n#{str}"
      YAML.load(str)
    else
      @runq_socket.close
      @runq_socket = nil
      nil
    end

  rescue SystemCallError => e
    @runq_socket = nil
    log.warn e.message
    retry
  end
  
  def runq_send_ready
    runq_send! Runq::Request::WorkerReady.new(
      :host   => `hostname`.strip,
      :pid    => $$,
      :group  => group,
      :user   => user,
      :engine => engine,
      :cost   => cost
    )
  end
  
  def runq_send_reconnect
    runq_send! Runq::Request::WorkerReconnect.new(
      :worker_id      => worker_id
    )
  end
  
  def runq_send_update
    runq_send Runq::Request::WorkerUpdate.new(
      :worker_id      => worker_id,
      :frac_complete  => frac_complete
    )
  end
  
  def runq_send_finished
    runq_send! Runq::Request::WorkerFinishedRun.new(
      :worker_id      => worker_id
    )
  end
  
  def execute
    runq_send_ready
    resp = runq_recv!
    @worker_id = resp["worker_id"] ###

    loop do
      while req = runq_recv!
        case req["message"] ###
        when "sending scenario"
          execute_one_run
        else
          ## error messages
          ## status request
          ## abort request
        end
      end

      log.info "Server closed the message socket."
    end

  rescue Exception => e
    log.error [e.inspect, *e.backtrace].join("\n  ")
  end
end
