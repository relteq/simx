require 'dpool/base'

class DataPool
  class BhlDaily::Station < Base
    attr_reader :station_id
    attr_reader :date

    URL_TEMPLATE = "http://bhl-loops.ccit.berkeley.edu/30s_daily/summary-%d"

    def initialize dpool, station_id, date
      super dpool
      @station_id = station_id
      @date = date
    end

    def url
      @url ||= URL_TEMPLATE % station_id
    end

    def filename
      date.strftime "bhl_30s_daily_summary_s#{station_id}_%Y_%m_%d.txt"
    end

    def dirname
      File.join(dpool.data_dir, "bhl", "daily",
        date.year.to_s, date.month.to_s)
    end

    def filepath
      File.join(dirname, filename)
    end

    def download_exists?
      File.exists? filepath
    end

    def do_download
      if download_exists?
        log.info "File already exists at #{filepath}, assuming correct"
          ## would be better to check against md5 sum
        return
      end

      download url do |download_path|
        log.debug "Downloaded #{url} to #{download_path}"

        FileUtils.makedirs dirname
        FileUtils.mv download_path, filepath
        log.debug "Moved #{url} to #{filepath}"

        log.info "Archived #{filename}"
      end

    rescue DownloadError => e
      log.warn e.message
    end
  end
end
