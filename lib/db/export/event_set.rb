require 'db/export/event'

module Aurora
  class EventSet 
    def to_xml(build_object = nil)
      if build_object
        to_xml_with_build_object(build_object)
      else
        builder = Nokogiri::XML::Builder.new do |xml|
          to_xml_with_build_object(xml)
        end
        builder.to_xml
      end 
    end

    def to_xml_with_build_object(xml)
      xml.EventSet(:id => self.id) {
        self.events.each do |e|
          e.to_xml(xml)
        end
      }
    end
  end
end
