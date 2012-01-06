require 'thwait'

require 'dpool/base'
require 'dpool/clearinghouse-dataset'

class DataPool
  # Listens on the download_request_queue; requests specify district,
  # date, and a handler for the received file.
  ## generalize for downloads from arbitrary urls (assumed unchanging?)
  class RequestDownloader < Base
    attr_reader :pending

    def run
      @pending = {}
      @thwait = ThreadsWait.new

      queue_handler = Thread.new do
        loop do
          request = dpool.download_request_queue.pop
          log.info "Download requested: #{request.inspect}"
          handle_request(request)
        end
      end
      queue_handler[:name] = "request queue handler"
      
      @thwait.join_nowait queue_handler
    
      @thwait.all_waits do |thread|
        log.info "Thread for #{thread[:name]} stopped"
        thread.join
      end

    rescue => e
      ## should this stop other threads?
      ## tell other pending requests to re-try?
      log.error "error in #{self}: #{e.message}:\n#{e.backtrace.join("\n  ")}"
      sleep 5
      log.info "restarting #{self}"
      retry
    end
    
    def handle_request request
      key = [request.district, request.date]
      
      if pending[key]
        pending[key].add_notifier do |filepath|
          request.notify filepath
        end

      else
        pending[key] = request
        
        thread = Thread.new do
          ds = ClearinghouseDataset.new dpool, request.district, request.date
          ds.download
          pending.delete key # must do this *before* notify

          log.info "Requested file is available: #{ds.filepath}"
          request.notify ds.filepath
        end
        thread[:name] = "downloading #{request.inspect}"
        
        @thwait.join_nowait thread
      end
    end
  end
end
