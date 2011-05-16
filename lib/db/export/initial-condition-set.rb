require 'db/export/initial-condition'

module Aurora
  class InitialConditionSet
    def build_xml(xml)
      xml.InitialConditionSet(:id => id, :name => name) {
        xml.description description unless description.empty?
        
        ics.each do |ic|
          ic.build_xml(xml)
        end
      }
    end
  end
end
