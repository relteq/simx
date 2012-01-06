require 'net/http'

class DataPool
  class Base
    attr_reader :dpool
    
    def initialize dpool
      @dpool = dpool
    end
    
    def log
      dpool.log
    end
    
    def yesterday
      Time.now - 24*60*60
    end
    
    class DownloadError < StandardError; end
    
    # must be called with block
    # yields path to file downloaded to the dpoold tmpdir
    # file is deleted after block closes
    def download uri_str
      unless block_given?
        raise ArgumentError, "no block given"
      end
      
      uri = URI.parse(uri_str)
      
      unless uri.scheme == "http"
        raise ArgumentError, "Wrong uri scheme: #{uri.scheme}"
      end
      if uri.query
        raise ArgumentError, "No query allowed in uri: #{uri.query}"
      end
      
      ## limit downloads per remote host to N (in config)
      
      filename = File.basename(uri.path)
      filepath = File.join(dpool.tmp_dir, filename)
      
      begin
        File.open(filepath, "wb") do |file|
          Net::HTTP.start(uri.host, uri.port) do |http|
            http.request_get(uri.path) do |response|
              case response
              when Net::HTTPSuccess
                response.read_body do |segment|
                  file.write(segment)
                  ## it would be nice to pass on pct completion to client
                end
              else
                raise DownloadError,
                  "when downloading #{uri}: #{response.message}"
              end
            end
          end
        end

        yield filepath
      ensure
        FileUtils.rm_f filepath
      end
    end
  end
end
