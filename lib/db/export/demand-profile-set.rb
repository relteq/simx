require 'db/export/demand-profile'

module Aurora
  class DemandProfileSet
    def build_xml(xml)
      xml.DemandProfileSet(:id => id, :name => name) {
        xml.description description
        
        dps.each do |dp|
          dp.build_xml(xml)
        end
      }
    end
  end
end
