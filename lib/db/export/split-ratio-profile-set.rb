require 'db/export/split-ratio-profile'

module Aurora
  class SplitRatioProfileSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless name.empty?
      
      xml.SplitRatioProfileSet(attrs) {
        xml.description description unless description.empty?
        
        srps.each do |srp|
          srp.build_xml(xml)
        end
      }
    end
  end
end
