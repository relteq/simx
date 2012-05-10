require 'rinda/rinda'

class Leia
  def initialize uri
    DRb.start_service ## idempotent?
    Rinda::TupleSpaceProxy.new(DRbObject.new(nil, uri))
  end
end

helpers do
  def leia
    LEIA ||= Leia.new(ENV['DEMO_RINDA_URI'] || "druby://localhost:6789"
  end
  
  def read_density_from_leia ts
    $leia_cache ||= {}
    
    if $leia_cache[ts]
      return $leia_cache[ts]
    end
    
    begin
      _, _, dmap = LEIA.read([:density_response, ts, Hash])
    rescue => e
      log.warn "leia read error: #{e}"
      sleep 2
      retry
    end
    
    if dmap
      $leia_cache[ts] = dmap)
    end
    return dmap
  end
  
  def request_predicted_density_from_leia d_map, ts_start, ts_delta = 5*60
    begin
      LEIA.write([:density_prediction_request, ts_start, ts_delta, d_map])
    rescue => e
      log.warn "leia write error: #{e}"
      sleep 2
      retry
    end
  end
end

