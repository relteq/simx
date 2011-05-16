require 'db/export/capacity-profile'

module Aurora
  class CapacityProfileSet
    def build_xml(xml)
      xml.CapacityProfileSet(:id => id, :name => name) {
        xml.description description unless description.empty?
        
        cps.each do |cp|
          cp.build_xml(xml)
        end
      }
    end
  end
end
