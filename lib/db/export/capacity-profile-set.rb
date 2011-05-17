require 'db/export/capacity-profile'

module Aurora
  class CapacityProfileSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless name.empty?
      
      xml.CapacityProfileSet(attrs) {
        xml.description description unless description.empty?
        
        cps.each do |cp|
          cp.build_xml(xml)
        end
      }
    end
  end
end
