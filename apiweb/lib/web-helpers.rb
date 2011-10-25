helpers do
  def defer_cautiously
    EM.defer do
      begin
        yield
      rescue Exception => e
        LOGGER.error "error: #{request.url}, params=#{request.params.inspect}"
        LOGGER.error "error text: #{e.message}"
        LOGGER.error "error backtrace: #{e.backtrace.join("\n  ")}"
        status 500
        body { "Internal Error" }
      end
    end
  end

  def protected!
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

  def index_page
    MY_ENV[:index_page]
  end
end
