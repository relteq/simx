require 'dpool/pems-daily'
require 'dpool/bhl-daily'

class DataPool
  class PeriodicDownloader < Base
    def pems_daily
      @pems_daily = PemsDaily.new(dpool, yesterday)
    end
    
    def bhl_daily
      @bhl_daily = BhlDaily.new(dpool, yesterday)
    end
    
    def sources
      [pems_daily, bhl_daily]
    end
    
    def download_schedule
      sources.map {|source| source.next_download}.compact.sort
    end
    
    def run
      loop do
        do_periodic_download
        
        t_now = Time.now
        t_next = download_schedule.find {|t| t > t_now}

        log.info "periodic download thread: sleeping until #{t_next}"
        sleep t_next - t_now
        log.info "periodic download thread: awake"
      end
    
    rescue => e
      log.error "error in #{self}: #{e.message}:\n#{e.backtrace.join("\n  ")}"
      sleep 5
      log.info "restarting #{self}"
      retry
    end
    
    def do_periodic_download
      sources.each do |source|
        log.info "Checking periodic downloads for #{source}"
        source.do_download
      end
    end
  end
end
