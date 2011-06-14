require 'java'

def aurora
  Java::Aurora
end

class ProgressUpdater
  include aurora.service.Updatable
  
	java_signature 'void notify_update(int)'
	def notify_update(pct)
		puts "update: #{pct}% complete"
	end
end

