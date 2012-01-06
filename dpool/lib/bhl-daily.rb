require 'dpool/base'

class DataPool
  class BhlDaily < Base
    attr_reader :date

    STATION_IDS = 1..9
    
    require 'dpool/bhl-daily-station'

    def initialize dpool, date
      super dpool
      @date = date
    end

    def stations
      @stations ||= STATION_IDS.map {|sid| Station.new(dpool, sid, date)}
    end
    
    def next_download
      t_safe = Time.parse("11:20 AM UTC")
      
      if t_safe > Time.now
        t_safe
      else
        t_safe + 24*60*60
      end
    end

    def do_download
      stations.each do |station|
        station.do_download
      end
    end
  end 
end
