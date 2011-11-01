class Sinatra::Base
  attr_reader :given
  
  def process_route(pattern, keys, conditions, block = nil, values = [])
    route = @request.path_info
    route = '/' if route.empty? and not settings.empty_path_info?
    return unless match = pattern.match(route)
    values += match.captures.to_a.map { |v| force_encoding URI.decode(v) if v }

    if values.any?
      original, @params = params, params.merge('splat' => [], 'captures' => values)
      keys.zip(values) { |k,v| (@params[k] ||= '') << v if v }
    end

    @given = params
    catch(:pass) do
      conditions.each { |c| throw :pass if c.bind(self).call == false }
      block ? block[self, values] : yield(self, values)
    end
  ensure
    # params is reverted before the async block can be executed, so use
    # given instead in your route handlers.
    @params = original if original
  end
end

