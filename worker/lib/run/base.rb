module Run
  # An Event is sent from a run to its worker's event queue.
  class Event
    # Run finished normally.
    class Finished < Event
      attr_reader :data

      def initialize data
        @data = data
      end
    end

    # Run was aborted due to abort command (from user via runq).
    class Aborted < Event
    end

    # Run was stopped due to TERM signal (from admin via 'rake stop').
    class Stopped < Event
    end

    # Run failed due to crash or other problem.
    class Failed < Event
      attr_reader :message

      def initialize message
        @message = message
      end
    end

    # Periodic update on progress of computation.
    class Update < Event
    end

    class Blocked < Event
      attr_reader :operation_needed
      attr_reader :operation_params

      def initialize op, params
        @operation_needed = op
        @operation_params = params
      end
    end
  end

  class PrerequisitesNotMet < Exception
    attr_reader :operation_needed
    attr_reader :operation_params

    def initialize op, params
      @operation_needed = op
      @operation_params = params
    end
  end

  # Manages a single run in the context of a worker procress. Each Run subclass
  # contains logic to start the process and monitor its output. Subclass should
  # define: #work, #cleanup, and #results. It may overridde #status as well.
  # The #work implementation may need to call #update and #fail and to
  # periodically set the value of progress. These methods runs in the Run's own
  # thread, so it can perform blocking IO calls, #system, etc.
  class Base
    # The run sends messages (Run::Event instances) to the worker using this
    # queue.
    attr_reader :worker_event_queue

    attr_reader :log

    # Engine-specific parameter object.
    attr_reader :param

    # Index of the run in the batch. May combine with param to derive some
    # run-specific parameters.
    attr_reader :batch_index
    
    attr_reader :apiweb_host
    
    attr_reader :apiweb_port
    
    attr_reader :dpool_socket
    
    # Engine requested for this run (worker may support several engines).
    attr_reader :engine
    
    # Engine-specific opts from local config.
    attr_reader :engine_opts

    # Estimated fraction, in 0..1, of work completed in this run. If not
    # started yet, value is :waiting. Value is :failed, :aborted, or :stopped
    # in those states. When finished, values is :finished (so that rounding up
    # to 1.0 will not cause confusion).
    attr_reader :progress

    INTERPRETER = "ruby"

    def initialize h
      @worker_event_queue = h[:event_queue] || raise
      @log                = h[:log]         || raise
      @param              = h[:param]       || raise
      @batch_index        = h[:batch_index] || raise
      @apiweb_host        = h[:apiweb_host] || raise
      @apiweb_port        = h[:apiweb_port] || raise
      @dpool_socket       = h[:dpool_socket]
      @engine             = h[:engine]      || raise
      @engine_opts        = h[:engine_opts]
      
      @progress = :waiting
      @pending_prereq = nil
    end

    # Start a thread to perform and monitor the computation and send updates
    # to the Worker.
    def start
      if @thread
        raise "Called start on run which is already running."
      end

      @thread = Thread.new do
        run
      end
    end

    # Can be overridden to provide more detail.
    def status
      str = 
        case progress
        when :waiting
          "No current run, waiting for run request."
        when :failed
          "Run failed."
        when :aborted
          "Run aborted."
        when :stopped
          "Run stopped."
        when :finished
          "Finished run ##{batch_index} of batch."
        when 0...1
          "Working on run ##{batch_index} of batch."
        end
      log.info "Collecting status: #{str}"
      str
    end

    # Called from the worker in response to abort event from runq.
    def abort
      if Thread.current == @thread
        raise "Wrong thread."
      end

      if @thread && (0..1) === progress
        log.info "Aborting."
        @thread.raise Interrupt
        @progress = :aborted
        worker_event_queue << Event::Aborted.new
      else
        log.warn "Requested to abort, but not running."
      end
    end

    # Called from the WorkerManager in response to a TERM signal.
    def stop
      if Thread.current == @thread
        raise "Wrong thread."
      end

      if @thread && (0..1) === progress
        log.info "Stopping."
        @thread.raise Interrupt
        @progress = :stopped
        worker_event_queue << Event::Stopped.new
      else
        log.warn "Requested to stop, but not running."
      end
    end

  protected

    def run
      log.info "starting run in #{self.class}."
      prereqs
      log.info "starting run work in #{self.class}."
      work
      log.info "finishing run"
      finish
    rescue Interrupt
      log.info "run interrupted; worker may proceed."
    rescue PrerequisitesNotMet => prereq
      unless prereq.operation_needed == @pending_prereq
        worker_event_queue << Event::Blocked.new(
          prereq.operation_needed,
          prereq.operation_params
        )
        @pending_prereq = prereq.operation_needed
      end
      log.info "Waiting on unmet prerequisite #{prereq.inspect}"
      sleep 1
      retry
    rescue Exception => e
      log.error "error in run: " + [e.inspect, *e.backtrace].join("\n  ")
      @progress = :failed
      event = Event::Failed.new e.message
      worker_event_queue << event
    ensure
      begin
        cleanup
      rescue Interrupt
        log.warn "Interrupt during cleanup -- " +
          "may have left some temp files or running processes."
      end
    end

    # Should be overridden in subclass.
    def prereqs
      # Perform prerequisite tasks (for example, get runq to
      # export a scenario from the database)
    end

    # Should be overridden in subclass.
    def work
      # Start an external process and monitor its output etc.
    end

    # Should be overridden in subclass.
    def cleanup
      # Stop external processes etc.
    end

    # Should be overridden in subclass.
    def results
    end

    # Typically called by subclass code when progress changes.
    def update
      ## if progress > old progress + 5 or elapsed > 10s
      worker_event_queue << Event::Update.new
    end

    # Called only from the run thread. Not normally called from subclass code.
    def finish
      unless Thread.current == @thread
        raise "Wrong thread."
      end

      log.info "Finished."
      @progress = :finished
      event = Event::Finished.new results
      worker_event_queue << event
    end

    # Called only from the run thread. Maybe be called by subclass code
    # when some error condition is detected in the run.
    def fail message
      unless Thread.current == @thread
        raise "Wrong thread."
      end

      log.info "Failed."
      @progress = :failed
      event = Event::Failed.new message
      worker_event_queue << event

      raise Interrupt
    end
  end
end
