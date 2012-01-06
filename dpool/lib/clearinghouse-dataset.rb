require 'dpool/base'

class DataPool
  # Contains metadata for one clearinghouse dataset, which is defined
  # by district and date; these are used to construct the remote url and
  # local filepath.
  #
  # Our URL to access data from the clearinghouse has format:
  # http://pems.dot.ca.gov/dbx/D/YYYY/MM/FMT/DATASET/dD0_FMT_DATASET_YYYY_MM_DD.txt.gz
  #
  #    where:
  #    D       = district (3, 4, 5, ..., 12)
  #    YYYY    = year
  #    MM      = month as 2 digits with leading 0
  #    FMT     = text | hpms
  #    DATASET = station_5min  station_day   station_hour  station_raw
  #    D0      = district as 2 digits with leading 0
  #    DD      = day as 2 digits with leading 0
  #
  #    for example:
  # http://pems.dot.ca.gov/dbx/4/2011/08/text/station_5min/d04_text_station_5min_2011_08_31.txt.gz
  #
  #    As you can see, the district is specified in the name.
  #
  # Data in the clearinghouse is updated on a monthly basis. That is, today we
  # can access August and before, but not September. September data will show up
  # in the clearinghouse in October. For yesterday's data, see pems-daily.rb.
  #
  class ClearinghouseDataset < Base
    attr_reader :dpool, :district, :date

    URL_BASE = "http://pems.dot.ca.gov/dbx"

    def initialize dpool, district, date
      @dpool = dpool
      @district = district
      @date = date
    end

    def filename
      @filename ||=
        date.strftime("d#{"%02d" % district}_text_station_5min_%Y_%m_%d.txt")
    end

    def url
      @url ||= begin
        File.join(URL_BASE,
          district.to_s,
          date.year.to_s,
          "%02d" % date.month,
          "text", "station_5min",
          "#{filename}.gz")
      end
    end

    def dirname
      @dirname ||=
        File.join(dpool.data_dir, "pems", "clearinghouse",
          district.to_s, date.year.to_s, date.month.to_s)
    end

    def filepath
      @filepath ||= File.join(dirname, filename)
    end

    def download
      if File.exist? filepath
        log.info "File already exists at #{filepath}, assuming correct"
          ## would be better to check against md5 sum; pems should give us that
        return
      end

      log.info "Downloading clearinghouse file at #{url}"

      super url do |download_path|
        log.info "Downloaded #{url} to #{download_path}"

        out = `gunzip #{download_path} 2>&1`

        unless $?.success?
          log.warn "Failed to gunzip #{download_path}: #{out}"
          return
        end

        unzipped_path = download_path.sub(/\.gz/, "")
        log.info "Unzipped to #{unzipped_path}"

        FileUtils.makedirs dirname
        FileUtils.mv unzipped_path, filepath
      end

    rescue DownloadError => e
      log.warn e.message
    end
  end
end
