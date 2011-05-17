require 'db/export/demand-profile'

module Aurora
  class DemandProfileSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless !name or name.empty?
      
      xml.DemandProfileSet(attrs) {
        xml.description description unless !description or description.empty?
        
        dps.each do |dp|
          dp.build_xml(xml)
        end
      }
    end
  end
end
