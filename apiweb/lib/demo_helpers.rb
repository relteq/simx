require 'rinda/rinda'

# client to talk to a leia server running at a given uri
class Leia
  def initialize uri
    DRb.start_service unless DRb.primary_server ## ok?
    
    @proxy = Rinda::TupleSpaceProxy.new(DRbObject.new(nil, uri))
    @cache = {}
  end
  
  def cached? ts
    @cache.key? ts
  end
  
  def [](ts)
    @cache[ts]
  end
  
  def cache! ts, dmap
    if dmap
      @cache[ts] = dmap
    end
  end
  
  def read(*args)
    @proxy.read(*args)
  end
  
  def read_all(*args)
    @proxy.read_all(*args)
  end
  
  def write(*args)
    @proxy.write(*args)
  end
  
  def take(*args)
    @proxy.take(*args)
  end
end

helpers do
  def leia
    unless $LEIA
      uri = ENV['DEMO_RINDA_URI'] || "druby://localhost:6789"
      log.info "connecting to leia server at #{uri}"
      begin
        $LEIA = Leia.new(uri)
        log.info "connected to leia server at #{uri}"
      rescue => ex
        log.warn "cannot connect to leia server at #{uri}: #{ex}; retrying..."
        sleep 5
        retry
      end
    end
    $LEIA
  end
  
  def read_density_from_leia ts
    if leia.cached? ts
      log.debug "got cached data for t = #{ts}: #{leia[ts].inspect}"
      return leia[ts]
    end

    response =
      begin
        log.info "retreiving density prediction for t = #{ts}"
        leia.read_all([:density_response, ts, Hash])
      rescue => e
        log.warn "leia read error: #{e}"
        sleep 2
        retry
      end
    
    _, _, dmap = response.first
    if dmap
      log.info "received density prediction for t = #{ts}"
      leia.cache! ts, dmap
    else
      log.warn "density prediction not available for t = #{ts}"
    end
      
    return dmap
  end
  
  def request_predicted_density_from_leia dmap, ts_start, ts_delta
    ts_end = ts_start + ts_delta
    
    log.debug "checking local cache for t = #{ts_end}"
    return if leia.cached?(ts_end)
    
    log.debug "checking remote cache for t = #{ts_end}"
    dmap_responses = leia.read_all([:density_response, ts_end, Hash])

    log.debug {
      "checked remote cache for t = #{ts_end};" +
      " found #{dmap_responses.size} entries"
    }

    if not dmap_responses.empty?
      leia.cache! ts_end, dmap_responses[0][2]
      return
    end

    begin
      log.info "requesting density prediction for t = #{ts_start} + #{ts_delta}"
      leia.write([:density_prediction_request, ts_start, ts_delta, dmap])
    rescue => e
      log.warn "leia write error: #{e}"
      sleep 2
      retry
    end
  end
end

