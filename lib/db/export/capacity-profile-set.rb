require 'db/export/capacity-profile'

module Aurora
  class CapacityProfileSet
    def build_xml(xml)
      xml.CapacityProfileSet(:id => id, :name => name) {
        xml.description description
        
        cps.each do |cp|
          cp.build_xml(xml)
        end
      }
    end
  end
end
