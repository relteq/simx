require 'db/export/split-ratio-profile'

module Aurora
  class SplitRatioProfileSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless !name or name.empty?
      
      xml.SplitRatioProfileSet(attrs) {
        xml.description description unless !description or description.empty?
        
        srps.each do |srp|
          srp.build_xml(xml)
        end
      }
    end
  end
end
