require 'dpool/base'

class DataPool
  class LocalServer < Base
    def run
      log.info "Local server listening on #{dpool.pub_name}"
      FileUtils.rm_f dpool.pub_name
      svr = UNIXServer.open(dpool.pub_name)
      
      loop do
        ## this will block additional sessions that might be capable of
        ## proceeding without the results of the executing session
        Thread.new(svr.accept) do |s|
          handle_session s
        end
      end
    
    rescue => e
      log.error "error in #{self}: #{e.message}:\n#{e.backtrace.join("\n  ")}"
      sleep 5
      log.info "restarting #{self}"
      svr.close unless svr.closed?
      retry
    end
    
    # The client can send multiple requests, one line each, of form:
    #
    #   type: specifics
    #
    # If type is 'pems' or 'PeMS Data Clearinghouse', specifics should be
    #
    #   district, date
    #
    # where district is either "dN", or just "N", for some district number N,
    # and date is any legal date spec, such as "Jan 1, 2011".
    #
    # If type is 'dbx' or 'Caltrans DBX', specifics should be
    #
    #   date
    #
    # If type is 'bhl', specifics should be 
    #
    #   station, date
    #
    # The response is the filename of the requested data, on a single line
    # (note: including newline).
    #
    def handle_session s
      while msg = s.gets
        log.info "Local socket received request for #{msg}"
        
        type, params = msg.match(/\s*([^:]*)\s*:\s*(.*)/i).captures
        
        case type
        when /pems/i
          district, date = params.match(/\s*d?(\d+)\s*,(.*)/i).captures
          handle_pems_request s, district.to_i, Time.parse(date)
        
        when /dbx/i
          date = params
          handle_dbx_request s, Time.parse(date)
        
        when /bhl/i
          station, date = params.match(/\s*(\d+)\s*,(.*)/i).captures
          handle_bhl_request s, station.to_i, Time.parse(date)
        
        else
          log.warn "bad request"
        end
      end
    
    rescue => e
      log.error "error in session: #{e.message}:\n#{e.backtrace.join("\n  ")}"
    end
    
    def handle_pems_request s, district, date
      log.info "handling request for pems data, " +
        "district = #{district}, date = #{date}"
      
      req = DownloadRequest.new(district, date) { |filepath|
        s.puts filepath
      }
      dpool.download_request_queue.push req
    end
    
    def handle_dbx_request s, date
      log.info "handling request for dbx data, date = #{date}"
      
      filepath = PemsDaily.new(dpool, date).filepath
      if File.exists?(filepath)
        log.info "dbx file exists: #{filepath}"
      else
        log.warn "dbx file does not exist: #{filepath}"
        ## what else to do?
      end
      
      s.puts filepath
    end
    
    def handle_bhl_request s, station, date
      log.info "handling request for bhl data, " +
        "station = #{station}, date = #{date}"
      
      filepath = BhlDaily::Station.new(dpool, station, date).filepath
      if File.exists?(filepath)
        log.info "bhl file exists: #{filepath}"
      else
        log.warn "bhl file does not exist: #{filepath}"
        ## what else to do?
      end
      
      s.puts filepath
    end
  end
end
