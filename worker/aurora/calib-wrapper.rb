require 'java'
require 'progress_updater'

def aurora
  Java::Aurora
end


xml_out = "calib.xml"
xml_in = File.read("test2.xml")
inpts = [xml_in, "http://vii.path.berkeley.edu/~gomes/fdcalibrate/d04_text_station_5min_2010_12_07.txt", "http://vii.path.berkeley.edu/~gomes/fdcalibrate/d04_text_station_5min_2010_12_08.txt", "http://vii.path.berkeley.edu/~gomes/fdcalibrate/d04_text_station_5min_2010_12_09.txt"]
inpts = [xml_in]
out = [xml_out]

updater = ProgressUpdater.new
manager = aurora.service.CalibrationManager.new

result = manager.run_application(inpts, out, updater, 1)
puts "result = #{result.inspect}",
     "xml dumped to #{xml_out.inspect}"
