require 'open-uri'
require 'tmpdir'

require 'worker/run/base'

# Do not require java (or updater) at load time, because we need to load this
# class and run its class methods from worker manager. However, it is
# instantiated only when run in jruby.

module Run
  class Aurora < Base
    # Param hash sent from user via runq. Keys are:
    #
    #   aurora_config:  <url to aurora xml file OR actual xml string>
    #   update_period:  <integer, in seconds>
    #   xml_dump:       <true or false; default is false>
    #
    attr_reader :param
    
    # xml string or url of xml string
    attr_reader :aurora_config
    
    # period between updates in seconds
    attr_reader :update_period
    
    # Should the final state of the run (if this is simulation) be
    # dumped to xml as part of the results?
    attr_reader :xml_dump
    
    INTERPRETER = "jruby"

    def initialize *args
      super
      @aurora_config = param["aurora_config"]
      @update_period = param["update_period"] || 10
      @xml_dump = param["xml_dump"]
    end
    
    def aurora
      Java::Aurora
    end
    
    def manager
      case engine
      when 'simulator'
        aurora.service.SimulationManager.new
      else
        raise "unknown engine: #{engine}"
      end
    end

    def work
      require 'rest-client' # only need this gem in java
      require 'worker/updater' # this depends on java
      Dir.mktmpdir "aurora-" do |dir|
        work_in_dir dir
      end
    end
    
    def work_in_dir dir
      @progress = 0; update

      case aurora_config
      when /\n/ # multiple lines; assume xml
        log.info "assuming xml given: #{aurora_config[0..50]}"
        input_xml = aurora_config
      else # single line, assume url
        log.info "reading url: #{aurora_config}"
        input_xml = open(aurora_config) {|f| f.read}
      end

      outfile = File.join(dir, "aurora.out")
      out = [outfile]

      if xml_dump
        xmloutfile = File.join(dir, "aurora.xml")
        out << xmloutfile
      end

      updater = ProgressUpdater.new do |pct|
        log.info "ProgressUpdater: #{pct}%"
        @progress = pct / 100.0; update
      end

      error = nil
      begin
        manager.run_application([input_xml], out, updater, update_period)
      rescue => e
        error = e
      end
      
      output_str = File.read(outfile)
      output_xml = xml_dump && File.read(xmloutfile)
      
      log.debug "output:\n#{output_str[0..200]}"
      log.debug "xml dump:\n#{output_xml[0..200]}"
      
      @results = {
        "result"          => !error,
        "output_str_url"  => store(output_str),
        "output_xml_url"  => output_xml && store(output_xml, "xml")
      }
      @results["error"] = error.to_s if error
      
      log.info "results = #{@results.to_yaml}"

      @progress = 1; update
    end

    def results
      @results
    end
    
    def store data, type = nil
      ### Worker should not know about this stuff.
      runweb_user = ENV["RUNWEB_USER"] || "relteq"
      runweb_password = ENV["RUNWEB_PASSWORD"] || "topl5678"

      expiry = 600 # seconds
      ext = type if type

      url = "http://" +
        "#{runweb_host}:#{runweb_port}/store?" +
        "expiry=#{expiry}"
      url << "&ext=#{ext}" if ext
      
      mime =
        case type
        when nil
          "text/plain"
        when "xml", :xml
          :xml
        end

      log.info "requesting storage from #{url}"
      rsrc = RestClient::Resource.new(url, runweb_user, runweb_password)
      response = rsrc.post data, :content_type => mime
      ## ok to go thru runweb?
      ## maybe a separate service, so runweb is not blocked?
      ## do these requests in parallel, and runweb uses async_post
      
      return "#{response.body}" ## use to_s instead?
    end

    def cleanup
      # nothing to do
    end
  end
end
