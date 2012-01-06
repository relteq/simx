require 'dpool/base'

class DataPool
  # PeMS data from yesterday is at the URL:
  #
  #    http://pems.dot.ca.gov/dbx/station_5min_summary_YYYY_MM_DD.txt.bz2
  #
  # where YYYY is year, MM - month, DD - day. For example,
  #
  #    http://pems.dot.ca.gov/dbx/station_5min_summary_2011_09_19.txt.bz2
  #
  # These files stay there for 24 hours and are renewed at 3 am every night.
  # These files contain data for _all_ PeMS VDS.
  #
  # For archives older than one month, see clearinghouse-dataset.rb.
  #
  class PemsDaily < Base
    attr_reader :date

    URL_BASE = "http://pems.dot.ca.gov/dbx"
    
    def initialize dpool, date
      super dpool
      @date = date
    end

    def next_download
      t_safe = Time.parse("11:30 AM UTC")
        # The PeMS update is 3:00 AM, but that may be PDT or PST. To be safe,
        # assume the later of the two, and schedule the download for 0:30
        # after that.
      
      if t_safe > Time.now
        t_safe
      else
        t_safe + 24*60*60
      end
    end

    def filename
      date.strftime "station_5min_summary_%Y_%m_%d.txt"
    end
    
    def url
      File.join(URL_BASE, filename + ".bz2")
    end
    
    def dirname
      File.join(dpool.data_dir, "pems", "daily",
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
          ## would be better to check against md5 sum; pems should give us that
        return
      end
      
      download url do |download_path|
        log.debug "Downloaded #{url} to #{download_path}"
        
        out = `bunzip2 #{download_path} 2>&1`

        unless $?.success?
          log.warn "Failed to bunzip2 #{download_path}: #{out}"
          return
        end

        unzipped_path = download_path.sub(/\.bz2/, "")
        log.debug "Unzipped to #{unzipped_path}"
        
        FileUtils.makedirs dirname
        FileUtils.mv unzipped_path, filepath
        log.debug "Moved to #{filepath}"
        
        log.info "Archived #{filename}"
      end
    
    rescue DownloadError => e
      log.warn e.message
    end
  end
end
