require 'nokogiri'
require 'socket'

class Run::Aurora
  # Wraps the aurora calibrator so that we can use the data pool server to
  # cache data files locally:
  #
  #  * checks input url with dpool to get a local file
  #
  #  * replaces local file url (file:...) with the original url
  #
  #  * copies output FD elements back into original xml
  #
  # If there is no dpool socket specified in the config, default to just
  # using CalibrationManager, which will download urls etc.
  #
  class CalibrationManagerWrapper
    attr_reader :calibration_manager
    attr_reader :dpool_socket
    attr_reader :log
    
    def initialize calibration_manager, dpool_socket, log
      @calibration_manager = calibration_manager
      @dpool_socket = dpool_socket
      @log = log
    end
    
    def dpsock
      @dpsock ||= UNIXSocket.open(dpool_socket)
    end
    
    def run_application *args
      if dpool_socket
        log.debug "calibrating with dpool"
        run_with_dpool *args
      else
        log.debug "calibrating without dpool"
        calibration_manager.run_application *args
      end
    end
    
    def run_with_dpool input_strings, output_files, updater, update_period
      xml_string = input_strings[0]
      xml = Nokogiri.XML(xml_string)
      
      revert = {}
      
      xml.xpath('//sensor//source').each do |source|
        url = source["url"] ## validate?
        case url
        when /^(pems|dbx|bhl)/i ## or maybe just ask dpool and handle failure?
          
          if md = /(\d+)\s*-\s*(\d+)/.match(url) # Jan 1-5, 2011
            date_begin = md[1].to_i
            date_end = md[2].to_i
            if date_end < date_begin
              raise ArgumentError, "Bad date range: #{url}"
            end
            
            file_urls = (date_begin..date_end).map do |date|
              date_url = url.sub(md[0], date.to_s)
              dpsock.puts date_url
              path = dpsock.gets ## handle errors
              file_url = path && "file://#{path.chomp}"
            end
            file_urls = file_urls.compact
            
            if not file_urls.empty?
              file_urls_csv = file_urls.join(",") # understood by calibrator
              source["url"] = file_urls_csv
              revert[file_urls_csv] = url
              log.debug {"substituted data source %p => %p" %
                [url, file_urls_csv] }
            end
            
          else
            dpsock.puts url
            path = dpsock.gets ## handle errors

            if path
              path = path.chomp
              file_url = "file://#{path}"
              source["url"] = file_url
              revert[file_url] = url
              log.debug {"substituted data source %p => %p" % [url, file_url] }
            end
          end
        end
      end
      
      if revert.empty?
        result = calibration_manager.run_application(
          input_strings, output_files, updater, update_period)
        return result
      end
      
      result = calibration_manager.run_application(
        [xml.to_s], output_files, updater, update_period)
      
      output_file = output_files[0]
      
      calibrated_xml = Nokogiri.XML(File.read(output_file))

      calibrated_xml.xpath('//sensor//source').each do |source|
        url = source["url"]
        if revert[url]
          source["url"] = revert[url]
        end
      end
      
      File.open(output_file, "w") do |f|
        f.puts calibrated_xml
      end
      
      return result ## needed?
    end
  end
end

