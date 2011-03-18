require 'logger'
require 'thread'
require 'thwait'
require 'fileutils'
require 'tempfile'
require 'tmpdir'
require 'yaml'

require 'worker/worker'
require 'worker/run/dummy'
require 'worker/run/generic'
require 'worker/run/calibrator'

# Daemon that starts sets of workers as child processes.
# If a worker dies, restarts it. Each worker has a specified run_class, which
# determines the class of the sequence of Run instances it manages.
class WorkerManager
  # Name of this WorkerManager instance, as referred to in the config.yaml
  # (as a top-level key in the hash).
  attr_reader :instance_name
  
  # Contains string keys: log_file, log_level, runq_host, runq_port,
  # runweb_host, runweb_port, workers, nstance_name. The value at workers has
  # ikeys run_class, count, group, etc.
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

    threads = []
    
    workers.each do |worker_set|
      worker_set["count"].times do
        w = worker_set.dup # note shallow copy
        w.delete "count"
        
        w["runq_host"] = config["runq_host"]
        w["runq_port"] = config["runq_port"]
        
        w["runweb_host"] = config["runweb_host"]
        w["runweb_port"] = config["runweb_port"]
        
        w["logdev"] = config["log_file"]
        threads << Thread.new(w) do |worker_spec|
          run_worker worker_spec
        end
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
    run_class = get_scoped_constant(worker_spec["run_class"])

    loop do
      log.info "starting worker for spec:\n#{worker_spec.to_yaml}"
      pid = fork do
        $0 = "#{run_class} worker for #{instance_name}"
        Worker.new(run_class, worker_spec).execute
      end
      log.info "started #{run_class} worker in pid=#{pid}"
      Process.waitpid pid

      if $?.exitstatus == 0
        # no error, just responding to TERM
        break
      else
        log.info "Restarting worker."
      end
    end
  
  rescue => e
    log.error ["In thread for #{worker_spec["run_class"]}:",
      e.inspect, *e.backtrace].join("\n  ")
    ## how to report this to 'rake stat'?
  end
end
