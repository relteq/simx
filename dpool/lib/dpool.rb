require 'logger'
require 'fileutils'
require 'timeout'
require 'thread'
require 'thwait'
require 'socket'
require 'time'
require 'argos'

require 'dpool/periodic-downloader'
require 'dpool/local-server'
require 'dpool/request-downloader'

class DataPool
  # seconds we wait for any request to finish
  REQUEST_TIMEOUT = 100
  
  NETWORK_ERRORS = [Errno::ECONNRESET, Errno::ECONNABORTED,
    Errno::ECONNREFUSED,
    Errno::EPIPE, IOError, Errno::ETIMEDOUT]
  
  ## this is really just a pems request -- generalize it
  class DownloadRequest
    attr_reader :district, :date

    def initialize district, date, &notifier
      @district = district
      @date = date
      @notifiers = []
      @notifiers << notifier
    end
    
    def add_notifier(&notifier)
      @notifiers << notifier
    end
    
    def notify filepath
      @notifiers.each {|n| n.call filepath}
    end
  end
  
  attr_reader :download_request_queue
  
  def initialize opts = {}
    @opts = opts

    @thwait = ThreadsWait.new
    @download_request_queue = Queue.new
  end
  
  def self.parse_argv argv
    optdef = {
      "data-dir"  => proc {|dirname| File.expand_path(dirname)},
      "tmp-dir"   => proc {|dirname| File.expand_path(dirname)},
      "pub-name"  => proc {|sockname| File.expand_path(sockname)},
      "log-file"  => proc {|filename| File.expand_path(filename)},
      "log-level" => proc {|level| level.upcase}
    }

    Argos.parse_options(argv, optdef)
  end
  
  def get_opt name
    @opts[name] or (raise ArgumentError, "missing #{name}")
  end

  def data_dir
    @data_dir ||= get_opt("data-dir")
  end
  
  def tmp_dir
    @tmp_dir ||= get_opt("tmp-dir")
  end

  def pub_name
    @pub_name ||= get_opt("pub-name")
  end

  def log
    @log ||= Logger.new(@opts["log-file"] || $stderr, "weekly")
  end

  def run
    level = @opts["log-level"]
    if level && Logger::Severity.constants.include?(level)
      log.level = Logger::Severity.const_get(level)
    else
      log.level = Logger::DEBUG
    end
    
    log.info "Starting"

    [PeriodicDownloader, LocalServer, RequestDownloader].each do |c|
      th = Thread.new do
        c.new(self).run
      end
      log.info "Thread for #{c} starting"
      th[:class] = c
      @thwait.join_nowait th
    end
    
    @thwait.all_waits do |thread|
      log.info "Thread for #{thread[:class]} stopped"
      thread.join
      ## rescue NETWORK_ERRORS and restart thread?
    end

  rescue Interrupt, SignalException
    log.info "#{self} exiting"
    exit
  rescue Exception => e
    log.error "Main thread: " + [e.inspect, *e.backtrace].join("\n  ")
    raise
  end
end

if __FILE__ == $0
  DataPool.new(DataPool.parse_argv(ARGV)).run
end
