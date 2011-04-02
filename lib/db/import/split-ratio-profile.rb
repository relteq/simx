require 'db/model/split-ratio-profile'

module Aurora
  class SplitRatioProfile
    def self.from_xml splitratios_xml, scenario
      srp = create
      srp.import_xml splitratios_xml, scenario
      srp.save
      srp
    end
    
    def import_xml splitratios_xml, scenario
      self.dt       = Float(splitratios_xml["dt"])
      self.profile  = splitratios_xml.text
    end
  end
end

