require 'open-uri'
require 'tmpdir'
require 'mime/types'

require 'worker/run/base'

# Do not require java (or updater) at load time, because we need to load this
# class and run its class methods from worker manager. However, it is
# instantiated only when run in jruby.

module Run
  class Aurora < Base
    # Param hash sent from user via runq. Keys are:
    #
    #   update_period:  <integer, in seconds, default=10>
    #   inputs:         <array of urls of input files OR strings>
    #   output_types:   <array of strings specifying content-types of outputs>
    #
    # It is up to the run requestor to make sure that the input and output
    # specifications make sense with the requested engine, as follows.
    #
    #  calibrator:
    #   * Inputs
    #     [0]: xml buffer with scenario configuration
    #
    #   * Outputs
    #     [0]: name of the xml configuration file tha needs to be generated
    #
    #  simulator:
    #   * Inputs
    #     [0]: xml buffer with scenario configuration
    #     [1]: xml buffer with time range (optional), for example:
    #         <time_range begin_time="25200" duration="10800" />
    #
    #   * Outputs
    #     [0]: name of the output .csv file
    #     [1]: name of the xml configuration file (optional - present
    #          in the warm-up run)
    #
    #  report generator:
    #   * Inputs
    #     [0]: xml buffer with the report request
    #
    #   * Outputs
    #     [0]: name of the xml file containing the report data
    #
    #
    #  report exporter:
    #   * Inputs
    #     [0]: url pointing to xml file containing the report data
    #
    #   * Outputs
    #     [0]: name of the resulting file whose extension (.pdf, .ppt, .xls)
    #          indicates the type of export to be performed

    attr_reader :param
    
    # period between updates in seconds
    attr_reader :update_period
    
    # The inputs entries are assumed to be urls if they are one line.
    # Otherwise, the entry is assumed to be the complete input.
    attr_reader :inputs
    
    # Array of mime types that are expected from the engine.
    attr_reader :output_types
    
    INTERPRETER = "jruby"

    def initialize *args
      super
      @update_period = param["update_period"] || 10
      @inputs = param["inputs"] || []
      @output_types = param["output_types"] || []
    end
    
    def aurora
      Java::Aurora
    end
    
    def manager
      case engine
      when 'simulator'
        aurora.service.SimulationManager.new
      when 'calibrator'
        aurora.service.CalibrationManager.new
      when 'report generator'
        aurora.service.ReportManager.new
      when 'report exporter'
        aurora.service.ExportManager.new
      else
        raise "unknown engine: #{engine}"
      end
    end
    
    def input_strings
      @input_strings ||= inputs.map do |input|
        case input
        when /\n/,    # multiple lines; assume inline data, not url
              /^\s*</ # looks like single-line xml
          log.info "assuming inline data: #{input[0..50].inspect}"
          input
        else # assume url
          log.info "reading url: #{input}"
          open(input) {|f| f.read} ## prohibit or restrict local file?
        end
      end
    end

    def work
      require 'rest-client' # only need this gem in java
      require 'worker/updater' # this depends on java
      Dir.mktmpdir "aurora-" do |dir|
        work_in_dir dir
      end
    end
    
    def ext_for_mime_type mime
      type = MIME::Types[mime].first
      if type
        type.extensions.first # this seems to be right for pdf, ppt, xls
      end
    end
    
    def work_in_dir dir
      @progress = 0; update
      
      output_files = []
      output_types.each_with_index do |mime, i|
        ext = ext_for_mime_type(mime)
        f = File.join(dir, "output_#{i}")
        f << ".#{ext}" if ext
        output_files << f
      end

      updater = ProgressUpdater.new do |pct|
        log.debug "ProgressUpdater: #{pct}%"
        @progress = pct / 100.0; update
      end
      
      log.info {
        "running aurora #{engine} with inputs:\n  " +
        input_strings.map {|s|s[0..100].inspect}.join("\n  ")
      }

      log.info {
        "running aurora #{engine} with output files:\n  " +
        output_files.map {|s| s.inspect}.join("\n  ")
      }

      begin
        manager.run_application(input_strings, output_files,
          updater, update_period)
      rescue => e
        log.error e
        @results = {
          "ok"          => false,
          "output_urls" => [],
          "error"       => e.to_s
        }
        return
      end

      output_urls = output_files.zip(output_types).map do |file, type|
        data = begin
          File.read(file)
        rescue => e
          log.warn "output file #{file} could not be read: #{e}"
          ""
        end
        
        log.debug "output #{file}:\n#{data[0..200].inspect}"
        store(data, type)
      end
      
      @results = {
        "ok"          => true,
        "output_urls" => output_urls
      }
      
      log.info "results = #{@results.to_yaml}"

      @progress = 1; update
    end

    def results
      @results
    end
    
    def store data, type = nil
      ## need option to store locally for debugging, not s3
      ### Worker should not know about this stuff.
      runweb_user = ENV["RUNWEB_USER"] || "relteq"
      runweb_password = ENV["RUNWEB_PASSWORD"] || "topl5678"

      expiry = 600 # seconds
      url = "http://" +
        "#{runweb_host}:#{runweb_port}/store?" +
        "expiry=#{expiry}"
            
      log.info "requesting storage from #{url} with type #{type}"
      rsrc = RestClient::Resource.new(url, runweb_user, runweb_password)
      response = rsrc.post data, :content_type => type
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
