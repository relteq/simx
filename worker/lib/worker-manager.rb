require 'logger'
require 'thread'
require 'thwait'
require 'fileutils'
require 'tempfile'
require 'tmpdir'
require 'yaml'

require 'worker/worker'
require 'worker/run/aurora'
require 'worker/run/dummy'
require 'worker/run/generic'

# Daemon that starts sets of workers as child processes.
# If a worker dies, restarts it. Each worker has a specified run_class, which
# determines the class of the sequence of Run instances it manages.
class WorkerManager
  # Name of this WorkerManager instance, as referred to in the config.yaml
  # (as a top-level key in the hash).
  attr_reader :instance_name
  
  # Contains string keys: log_file, log_level, runq_host, runq_port,
  # apiweb_host, apiweb_port, dpool_socket, workers, instance_name.
  # The value at workers has keys run_class, count, group, etc.
  attr_reader :config
  
  class << self
    def run argv = ARGV
      wmgr = new
      wmgr.parse_argv argv
      wmgr.run
    end
  end
  
  def parse_argv argv
    if argv.length != 1
      raise ArgumentError, "WorkerManager must be called with 1 arg"
    end
    @config = YAML.load(argv[0])
    @instance_name = @config["instance_name"] || "local"
  end
  
  def log
    @log ||= begin
      log = Logger.new(config["log_file"] || $stderr, "weekly")
      
      level = config["log_level"] || "info"
      level = level.upcase
      if Logger::Severity.constants.include?(level)
        log.level = Logger::Severity.const_get(level)
      else
        log.level = Logger::INFO
      end
      
      log
    end
  end
  
  def workers
    config["workers"]
  end
  
  def run
    log.info "#{self.class} starting."
    
    $0 = "#{self.class} for #{instance_name}"
    
    FileUtils.makedirs(Dir.tmpdir)
      # or else mktmpdir falls back to system tmp dir, which may be /tmp
      # which jruby fails to write to.

    if config["mode"] == "start" ## hack
      sid = Process.setsid
      log.info "sid = #{sid}"
      trap "TERM" do
        trap "TERM" do
          Process.waitall
          exit
        end
        Process.kill "TERM", -sid
        Process.waitall
        exit
      end
    end

    threads = []
    
    workers.each do |worker_set|
      run_class = get_scoped_constant(worker_set["run_class"])
      
      case run_class::INTERPRETER
      when "ruby"
        worker_set["count"].times do
          w = worker_set.dup # note shallow copy
          w.delete "count"

          w["runq_host"] = config["runq_host"]
          w["runq_port"] = config["runq_port"]

          w["apiweb_host"] = config["apiweb_host"]
          w["apiweb_port"] = config["apiweb_port"]

          w["dpool_socket"] = config["dpool_socket"]

          w["logdev"] = config["log_file"]

          w["instance_name"] = instance_name

          threads << Thread.new(w) do |worker_spec|
            run_worker worker_spec
          end
        end
      
      when "jruby"
        w = worker_set.dup # note shallow copy
        # let worker see "count" 

        w["runq_host"] = config["runq_host"]
        w["runq_port"] = config["runq_port"]

        w["apiweb_host"] = config["apiweb_host"]
        w["apiweb_port"] = config["apiweb_port"]

        w["dpool_socket"] = config["dpool_socket"]

        w["logdev"] = config["log_file"]

        w["instance_name"] = instance_name

        threads << Thread.new(w) do |worker_spec|
          run_worker worker_spec
        end
      
      else
        log.warn "unrecognized interpreter: #{run_class::INTERPRETER}"
      end
    end
    
    ThreadsWait.all_waits(*threads) do |thread|
      thread.join
    end

    log.info "#{self.class} done."
  end
  
  def get_scoped_constant str
    str.split("::").inject(Object) {|c,s|c.const_get s}
  end
  
  def run_worker worker_spec
    loop do
      ok = run_worker_once worker_spec
      if ok
        # no error, just responding to TERM or INT
        break
      else
        n = 1
        log.info "Restarting worker after #{n} seconds..."
        sleep n
      end
    end
  
  rescue => e
    log.error ["In thread for #{worker_spec["run_class"]}:",
      e.inspect, *e.backtrace].join("\n  ")
    ## how to report this to 'rake stat'?
  end
  
  def run_worker_once worker_spec
    log.info "starting worker for spec:\n#{worker_spec.to_yaml}"
    
    run_class = get_scoped_constant(worker_spec["run_class"])
    
    case interp = run_class::INTERPRETER
    when "jruby"
      run_worker_once_in_jruby worker_spec
    when "ruby"
      run_worker_once_in_ruby worker_spec
    else
      raise ArgumentError, "Unknown interpreter: #{interp}"
    end
  end

  def run_worker_once_in_jruby worker_spec
    require 'worker/aurora-classpath'
    
    log.info "Using CLASS_PREFIX = #{Aurora::CLASS_PREFIX}"

    run_class = get_scoped_constant(worker_spec["run_class"])
    
    rubylib = [ ENV['simx_lib'] , ENV['RUBYLIB'] ].compact.join(":")

    cmd = "env RUBYLIB=#{rubylib} " +
          "CLASSPATH=#{Aurora::CLASSPATH} " +
          "jruby " + "-J-Xmx512M " +
          "-e 'require \"worker/jruby-worker\"; JRubyWorker.new.run' " +
          "2>&1"
    
    log.info "starting jruby with: #{cmd.inspect}"
    
    # IO.popen should not be used in the same process that also forks, as in
    # run_worker_once_in_ruby below. So we need an additional fork here.
    fpid = fork do
      $0 = "#{run_class} jruby worker for #{instance_name}"

      result, pid = IO.popen(cmd, "r+") do |jruby|
        jruby.puts worker_spec.to_yaml
        jruby.close_write
        [jruby.read, jruby.pid]
      end

      case result
      when /^JRubyWorker error/i # might be mixed with aurora output
        log.warn "Error in jruby worker pid=#{pid}: #{result}"
        exit 1
      else
        log.info "Finished jruby worker pid=#{pid}: #{result}"
        exit 0
      end
    end

    log.info "started #{run_class} jruby worker, ppid=#{fpid}"

    begin
      Process.waitpid fpid
    rescue => e
      log.warn "run_worker_once_in_jruby: #{e.message}"
    end
    
    return ($?.exitstatus == 0)
  end
  
  def run_worker_once_in_ruby worker_spec
    run_class = get_scoped_constant(worker_spec["run_class"])
    pid = fork do
      begin
        $0 = "#{run_class} worker for #{instance_name}"
        Worker.new(run_class, worker_spec).execute
      rescue Interrupt
        exit
      rescue => e
        log.error e
        raise
      end
    end
    log.info "started #{run_class} worker pid=#{pid}"
    
    begin
      Process.waitpid pid
    rescue => e
      log.warn "run_worker_once_in_ruby: #{e.message}"
    end
    
    result = ($?.exitstatus == 0)
    log.info "Finished ruby worker pid=#{pid}: result=#{result}" 
    return result
  end
end
