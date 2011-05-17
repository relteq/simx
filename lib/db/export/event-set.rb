require 'db/export/event'

module Aurora
  class EventSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless name.empty?
      
      xml.EventSet(attrs) {
        xml.description description unless description.empty?
        
        events.each do |event|
          event.build_xml(xml)
        end
      }
    end
  end
end
