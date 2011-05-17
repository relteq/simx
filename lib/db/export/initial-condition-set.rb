require 'db/export/initial-condition'

module Aurora
  class InitialConditionSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless !name or name.empty?
      
      xml.InitialDensityProfile(attrs) {
        xml.description description unless !description or description.empty?
        
        ics.each do |ic|
          ic.build_xml(xml)
        end
      }
    end
  end
end
