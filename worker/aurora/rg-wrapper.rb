require 'java'
require 'progress_updater'

def aurora
  Java::Aurora
end


xml_out = "report.xml"
xml_in = File.read("request.xml")
inpts = [xml_in]
out = [xml_out]

updater = ProgressUpdater.new
manager = aurora.service.ReportManager.new

result = manager.run_application(inpts, out, updater, 1)
puts "result = #{result.inspect}",
     "xml dumped to #{xml_out.inspect}"
