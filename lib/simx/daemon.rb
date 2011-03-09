require 'timeout'

module Daemon
  REQUEST_TIMEOUT = 5
  
  def command cmd, sock_name
    require 'socket'
    begin
      s = UNIXSocket.open(sock_name)
      s.send(cmd, 0)
      Timeout.timeout REQUEST_TIMEOUT do
        s.recv(1000)
      end
    rescue TimeoutError => ex
      "timed out after #{REQUEST_TIMEOUT} seconds"
    rescue Errno::ENOENT
      "not running"
    rescue Errno::ECONNREFUSED => ex
      ex.message << " socket may be orphaned (power cycle?) -- try 'rake stop'"
      ex
    rescue Errno::ECONNRESET
      sleep 0.2
      retry  
    rescue StandardError => ex
      ex
    end
  end

  def print_stat sock_name, err_file
    stat = command("stat", sock_name)
    puts stat
    if err_file and /not running/i === stat and File.exist?(err_file)
      system "cat #{err_file}"
    end
  end

  def daemonize opts={}
    fork do
      Process.setsid

      fork do
        require 'socket'
        require 'fileutils'
        require 'logger'

        log_file = opts["log_file"]
        if log_file
          log_file = File.expand_path(log_file)
          log = Logger.new(log_file, *(opts["log_params"] || [10, 1_000_000]))
        else
          warn "no log_file specified for daemon"
          log = Logger.new(STDERR) # will be useless after reopen
        end
        log.level = Logger::DEBUG

        if opts["sock_name"]
          sock_name = File.expand_path(opts["sock_name"])
          ctrl = Controller.new(sock_name, log)
        end

        if opts["username"]
          require 'etc'
          user = Etc.getpwnam(opts["username"])
          Process::UID.change_privilege(user.uid)
        end

        Dir.chdir opts["daemon_dir"] if opts["daemon_dir"]
        ## File.umask 0 (why was this here?)

        $0 = opts["proc_name"] + " [monitor]" if opts["proc_name"]

        STDIN.reopen "/dev/null", "r"
        STDOUT.reopen opts["err_file"] || "/dev/null"
        STDERR.reopen STDOUT
        
        log.info "RUBYLIB = #{ENV['RUBYLIB']}; RUBYOPT = #{ENV['RUBYOPT']}"

        begin
          pid = fork do
            begin
              yield
            rescue => e
              log.error [e, *e.backtrace].join("\n  ")
              raise
            rescue Exception => e
              log.info e
              raise
            end
          end
          
          trap "TERM" do
            Process.kill "TERM", pid
            Process.waitpid pid
            exit
          end
          
          ctrl.run(pid) if ctrl
          Process.waitpid(pid)
          ctrl.finish if ctrl
          log.info "Monitor process exiting"
        
        rescue => e
          log.error [e, *e.backtrace].join("\n  ")
          raise
        end
      end
    end
  end
  
  # Manages a socket which responds to commands send by the #command method.
  class Controller
    protected
    
    attr_reader :svr, :pid, :log, :sock_name
    
    def initialize sock_name, log
      @sock_name = sock_name
      @log = log
      @cleanup = nil
      @svr = open_server
    end
    
    def run pid
      @pid = pid
      @thread = Thread.new do
        while handle_request; end
      end
      log.info "Monitor process managing daemon on socket #{sock_name}"
      log.info "Monitor process managing child pid = #{pid}"
    end
    public :run
    
    # Should be called after the child process exits.
    def finish
      @thread.kill if @thread; @thread = nil
      @cleanup.call if @cleanup; @cleanup = nil
      FileUtils.rm sock_name
    end
    public :finish

    def open_server
      tries = 0
      begin
        UNIXServer.open(sock_name)

      rescue Errno::EADDRINUSE => ex
        tries += 1
        if tries <= 3
          sleep 0.1
          retry
        else
          raise Errno::EADDRINUSE,
            "#{ex.message}: Someone else seems to be using the " +
            "socket #{sock_name} -- try deleting it"
        end
      end
    end
    
    def handle_request
      s = svr.accept
      msg = s.recv(1000)
      should_accept_more = true

      case msg
      when /\Astop\z/i
        @cleanup = proc do
          begin
            s.send "stopped", 0
          rescue Errno::EPIPE
          end
          s.close unless s.closed?
        end
        Process.kill("TERM", pid)
        should_accept_more = false
        # do not close s

      when /\Astat\z/i
        start_time,pcpu = `ps h -ostart_time,pcpu #{pid}`.split
        s.send "running, pid=#{pid}, start=#{start_time}," +
          " pcpu=#{pcpu}, ver=???", 0 ## version?
        s.close
      
      else
        s.send "unknown command: #{msg.inspect}"
        s.close
      end
      return should_accept_more

    rescue => ex
      log.error "error in handling socket request, continuing: " +
        "#{ex.class}: #{ex}\n" + ex.backtrace.join("\n  ")
    end
  end
end
