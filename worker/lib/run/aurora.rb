require 'open-uri'
require 'tmpdir'
require 'mime/types'
require 'nokogiri'

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
    #     [0]: name of the xml configuration file that needs to be generated
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
    #     [0]: url pointing to xml file containing the report data - must
    #          be wrapped in a <url> tag
    #
    #   * Outputs
    #     [0]: name of the resulting file whose extension (.pdf, .ppt, .xls)
    #          indicates the type of export to be performed
    #
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
        require 'worker/run/aurora/calibrator'
        CalibrationManagerWrapper.new(
          aurora.service.CalibrationManager.new, dpool_socket, log)
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
          log.info "reading url: #{input.inspect}"
          open(input) {|f| f.read} ## prohibit or restrict local file?
        end
      end
    end

    def update_with_info info_req
      if info_req.info_type == :param_update
        if info_req.info_value.include?(:scenario_url)
          log.debug "changing inputs[0] from #{inputs[0]} to #{info_req.info_value[:scenario_url]}"
          inputs[0] = info_req.info_value[:scenario_url]
          @pending_prereq = nil if @pending_prereq == :scenario_export
        else
          log.warn "unexpected info value in update_with_info #{info_req.info_value}"
        end
      else
        log.warn "unexpected info type in update_with_info #{info_req.inspect}"
      end
    end

    def prereqs
      if inputs.first =~ /@scenario/
        raise PrerequisitesNotMet.new(:scenario_export, inputs.first)
      end
    end

    def work
      require 'rest-client' # only need this gem in java
      require 'worker/updater' # this depends on java
      Dir.mktmpdir "aurora-" do |dir|
        work_in_dir dir
      end
    end
    
    def ext_for_mime_type mime_type
      type = MIME::Types[mime_type].first
      if type
        type.extensions.first # this seems to be right for pdf, ppt, xls
      end
    end
    
    def work_in_dir dir
      @progress = 0; update
      
      output_files = []
      output_types.each_with_index do |mime_type, i|
        ext = ext_for_mime_type(mime_type)
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
        input_strings.map {|s|s[0..100].inspect + "..."}.join("\n  ")
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

      output_urls = output_files.zip(output_types).map do |file, mime_type|
        data = begin
          File.read(file) ## maybe we don't need to read it
        rescue => e
          log.warn "output file #{file} could not be read: #{e}"
          ""
        end
        
        log.debug "output #{file}:\n#{data[0..200].inspect}"
        log.debug "output file size=#{File.size(file)}"
        File.open(file) do |f|
          store(f, mime_type)
        end
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

    # stores data using apiweb's storage service; returns url to the data
    def store data, mime_type = nil
      ### Worker should not know about this stuff.
      ### tmp creds could be supplied in the run request sent to the worker?
      apiweb_user = ENV["APIWEB_USER"] || "relteq"
      apiweb_password = ENV["APIWEB_PASSWORD"] || "topl5678"

      expiry = 24*60*60 ## ok?
      ext = ext_for_mime_type(mime_type) if mime_type

      post_url = "http://" +
        "#{apiweb_host}:#{apiweb_port}/webtmp?" +
        "expiry=#{expiry}&ext=#{ext}"

      log.info "requesting storage from #{post_url}"
      rsrc = RestClient::Resource.new(post_url, apiweb_user, apiweb_password)
      
      log.debug "storing #{data.inspect[0..200]}"
      response = rsrc.post(:file => data, :multipart => true)

      data_url = "#{response.body}" ## to_s instead?

      log.info "results stored at #{data_url.inspect}"
      data_url
    end

    def cleanup
      # nothing to do
    end
  end
end
