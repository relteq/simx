helpers do
  def stream_cautiously
    # This will not be necessary after the following is fixed:
    # https://github.com/sinatra/sinatra/issues/426
    stream do |out|
      begin
        yield out if block_given?
      rescue Exception => e
        log.error "error: #{request.url}, params=#{request.params.inspect}"
        log.error "error text: #{e.message}"
        log.error "error backtrace: #{e.backtrace.join("\n  ")}"
        status 500
        body { "Internal Error" }
      end
    end
  end
  
  def university_of_california_at_berkeley?
    /berkeley\.edu$/i === ENV['HOSTNAME']
  end

  def protected!
    return unless university_of_california_at_berkeley?
    
    response['WWW-Authenticate'] = %(Basic realm="the TOPL Project") and \
    throw(:halt,
          [401, "Not authorized at #{request.env["REMOTE_ADDR"]}\n"]) and \
    return unless authorized?
  end

  def not_authorized!
    throw(:halt,
          [403, "Unauthorized request: Try returning to relteq.com"])
  end

  def authorized?
    TRUSTED_ADDRS.include?(request.env["REMOTE_ADDR"]) or begin
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials &&
        USERS.include?(@auth.credentials)
    end
  end

  def can_access?(object, access_token)
    return true if TRUSTED_ADDRS.include?(request.env["REMOTE_ADDR"])

    unexpired_auths =
      DB[:api_authorizations].filter('expiration > ?', Time.now.utc)
    applicable_to_object = unexpired_auths.filter(
      :object_id => object[:id], 
      :object_type => object[:type],
      :access_token => access_token
    )
    applicable_to_object.all.count == 1 
  end

  def digest(*args)
    Digest::MD5.hexdigest(args.join)
  end

  def index_page
    MY_ENV[:index_page]
  end

  # Yields open File (if uploaded with multipart) or, deprecated,
  # String (from body, otherwise).
  def get_upload
    file_field = params["file"]
    
    if file_field
      log.debug "file_field = #{file_field.inspect}"

      begin
        f = file_field[:tempfile]
        log.debug "upload tempfile = #{f.inspect}"
        yield f
      ensure
        f.close
        f.unlink
      end

    else ## temporarily allow this legacy case for old NE
      log.warn "missing 'file' param; assuming data is in body"
      yield request.body.read
    end
  end
end
