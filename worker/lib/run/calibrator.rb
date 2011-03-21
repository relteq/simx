require 'worker/run/base'

require 'tmpdir'
require 'open-uri'
require 'rest-client'

module Run
  class Calibrator < Base
    # Param hash sent from user via runq. Keys are:
    #
    #   aurora_config
    #
    attr_reader :param
    
    # xml string
    attr_reader :aurora_config
    
    # path to jar file of calibrator
    attr_reader :jar_file
    
    # path to sensor file
    attr_reader :sensor_file

    def initialize *args
      super
      @aurora_config = param["aurora_config"]
      
      unless engine_opts
        raise ArgumentError, "missing engine_opts"
      end

      @jar_file = engine_opts["jar_file"] or
        raise ArgumentError, "missing jar_file"

      @sensor_file = engine_opts["sensor_file"] or
        raise ArgumentError, "missing sensor_file"
    end
    
    def run
      Dir.mktmpdir "calibrator-" do |dir|
        begin
          @dir = dir
          super
        ensure
          @dir = nil
        end
      end
    end
    
    def output_xml_file
      "output.xml"
    end

    def work
      @progress = 0; update
      
      case aurora_config
      when /\n/ # multiple lines; assume xml
        log.info "assuming xml given: #{aurora_config[0..50]}"
        input_xml = aurora_config
      else # single line, assume url
        log.info "reading url: #{aurora_config}"
        input_xml = open(aurora_config) {|f| f.read}
      end

      input_xml_file = File.join(@dir, "input.xml")
      File.open(input_xml_file, "w") do |f|
        f.puts input_xml
      end
      
      pid = fork do
        Dir.chdir @dir
        
        $stdout.reopen "out"
        $stderr.reopen "err"
        
        cmd = %w{ java -jar }
        cmd << jar_file
        cmd << input_xml_file
        cmd << sensor_file
        cmd << output_xml_file
        
        exec *cmd
      end
      Process.waitpid pid
      
      if not $?.success?
        err = File.read(File.join(@dir, "err"))
        out = File.read(File.join(@dir, "out"))
        fail out + err
      end
      
      @progress = 1; update
    end

    def results
      output_xml = File.read(File.join(@dir, output_xml_file))
      
      ### Worker should not know about this stuff.
      runweb_user = ENV["RUNWEB_USER"] || "relteq"
      runweb_password = ENV["RUNWEB_PASSWORD"] || "topl5678"

      expiry = 60 # seconds
      ext = "xml"

      url = "http://" +
        "#{runweb_host}:#{runweb_port}/store?" +
        "expiry=#{expiry}&ext=#{ext}"

      log.info "requesting storage from #{url}"
      rsrc = RestClient::Resource.new(url, runweb_user, runweb_password)
      response = rsrc.post output_xml, :content_type => :xml
      output_xml_url = "#{response.body}"
      ## ok to go thru runweb?
      ## maybe a separate service, so runweb is not blocked?

      log.info "results stored at #{output_xml_url}"
      output_xml_url
    end

    def cleanup
    end
  end
end
