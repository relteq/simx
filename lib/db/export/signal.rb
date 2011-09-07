require 'db/export/phase'

module Aurora
  class Signal
    def build_xml(xml)
      xml.signal(:node_id => node_id) {
        phases.each do |phase|
          phase.build_xml(xml)
        end
      }
    end
  end
end
