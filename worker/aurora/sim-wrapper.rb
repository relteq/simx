require 'java'
require 'progress_updater'

def aurora
  Java::Aurora
end

xml_in = File.read("test.xml")
time_range = "<time_range begin_time=\"25200\" duration=\"10800\" />"
in_files = [xml_in, time_range]
outfile = "out.csv"
xml_out = "out.xml"
#xml_out = ""
out = [outfile, xml_out]
#out = [outfile]

updater = ProgressUpdater.new
manager = aurora.service.SimulationManager.new

result = manager.run_application(in_files, out, updater, 1)
puts "result = #{result.inspect}",
     "output is in #{outfile.inspect}",
     "xml dumped to #{xml_out.inspect}"
