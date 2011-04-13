require 'db/model/splitratio-profile'

module Aurora
  class SplitratioProfile
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

