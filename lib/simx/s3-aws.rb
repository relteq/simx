require 'aws/s3'

class S3_AWS
  attr_reader :bucket
  attr_reader :log
  
  def initialize opts
    @bucket = opts[:bucket]
    @log = opts[:log]
    AWS::S3::Base.establish_connection!(opts[:creds])
  end
  
  def fetch filename
    AWS::S3::S3Object.value filename, bucket
  end

  # +params+ can include "expiry", "ext"; returns url where +data+ is stored;
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
    key = Digest::MD5.hexdigest(data)
    if ext
      if /\./ =~ ext
        ext = ext[/[^.]*$/]
      end
      key << "." << ext
    end

    # check if key already exists on s3 and don't upload if so
    exists =
      begin
        AWS::S3::S3Object.find key, bucket
        true
      rescue AWS::S3::NoSuchKey
        false
      rescue => ex
        log.debug ex if log
      end
    
    if exists
      log.info "Data already exists in S3 at #{bucket}/#{key}" if log
      ## what if expiry is different? update it?
    
    else
      log.info "Storing in S3 at #{bucket}/#{key}" if log
      log.debug "expiry=#{expiry.inspect}, data: " + data[0..50] if log

      opts = {
        :access => :public_read
      }
      if params[:content_type]
        opts[:content_type] = params[:content_type]
      end

      if expiry
        opts["x-amz-meta-expiry"] = Time.at(Time.now + expiry)
        ### need daemon to expire things
      end

      AWS::S3::S3Object.store key, data, bucket, opts
    end
    
    url = AWS::S3::S3Object.url_for(key, bucket)
    log.info "url_for returned #{url}" if log

    return url
  end
end
