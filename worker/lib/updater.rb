require 'java'

module Run
  class Aurora::ProgressUpdater
    include Java::Aurora.service.Updatable
    
    def initialize(&bl)
      @updater = bl
    end

    java_signature 'void notify_update(int)'
    def notify_update(pct)
      @updater.call pct
    end
  end
end
