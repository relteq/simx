require 'db/export/event'

module Aurora
  class EventSet
    def build_xml(xml)
      xml.EventSet(:id => id, :name => name) {
        xml.description description unless description.empty?
        
        events.each do |event|
          event.build_xml(xml)
        end
      }
    end
  end
end
