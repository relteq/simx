require 'fsdb'

class S3_Mock
  attr_reader :dir
  attr_reader :url_base
  attr_reader :log
  
  attr_reader :db
  
  def initialize opts
    @dir = opts[:dir]
    @url_base = opts[:url_base]
    @log = opts[:log]
    
    @db = FSDB::Database.new(dir)
    db.formats = [
      FSDB::TEXT_FORMAT.when(//)
    ]
  end
  
  def fetch filename
    db[filename]
  end

  # +params+ can include "expiry", "ext"; returns url where +data+ is stored;
  # if +data+ is a File, then read it instead;
  # the url is based on the md5 hash of the data
  def store data, params
    expiry_str = params["expiry"]
    expiry =
      begin
        expiry_str && Float(expiry_str)
      rescue => e
        log.warn e if log
        nil
      end

    ext = params["ext"]

    require 'digest/md5'
    
    if defined? data.path
      key = Digest::MD5.file(data.path).hexdigest
      data = data.read
      ## would be better not to read the file, but rather copy it to fsdb
    else
      key = Digest::MD5.hexdigest(data)
    end
    
    
    if ext
      if /\./ =~ ext
        ext = ext[/[^.]*$/]
      end
      key << "." << ext
    end

    # check if key already exists and don't upload if so
    if db[key]
      log.info "Data already exists locally at #{key}" if log
      ## what if expiry is different? update it?
    
    else
      log.info "Storing in locally at #{key}" if log
      log.debug "expiry=#{expiry.inspect}, data: " + data[0..50] if log

      if expiry
## use fsdb metadata
##        opts["x-amz-meta-expiry"] = Time.at(Time.now + expiry)
##        ### need daemon to expire things
      end

      db[key] = data
    end
    
    url = File.join(url_base, key)
    log.info "url is #{url}" if log

    return url
  end
end
