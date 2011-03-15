require 'worker/run/base'

require 'tmpdir'

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

      input_xml_file = File.join(@dir, "input.xml")
      File.open(input_xml_file, "w") do |f|
        f.puts aurora_config
      end
      
      pid = fork do
        $stdout.reopen "out"
        $stderr.reopen "err"
        Dir.chdir @dir
        
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
      File.read(File.join(@dir, output_xml_file))
    end

    def cleanup
    end
  end
end
