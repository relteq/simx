module Aurora
  class Controller
    def to_xml(xml)
      xml.controller(:dt => self.dt, :type => self[:type]) {
        xml << self.parameters
      }
    end
  end
end
