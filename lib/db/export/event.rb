module Aurora
  class Event 
    def to_xml(xml)
      xml.event(:enabled => self.enabled, 
                :tstamp => self.time, 
                 :type => self[:type]) do
        xml << self.parameters
      end
    end
  end
end
