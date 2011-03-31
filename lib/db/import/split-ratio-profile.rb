require 'db/model/split-ratio-profile'

module Aurora
  class SplitRatioProfile
    def self.import_xml splitratios_xml
      srp = create
      
      srp.tp = Float(splitratios_xml["tp"])
      srp.profile = splitratios_xml.text
      
      srp.save
      srp
    end
  end
end

