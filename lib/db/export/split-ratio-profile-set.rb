require 'db/export/split-ratio-profile'

module Aurora
  class SplitRatioProfileSet
    def build_xml(xml)
      xml.SplitRatioProfileSet(:id => id, :name => name) {
        xml.description description unless description.empty?
        
        srps.each do |srp|
          srp.build_xml(xml)
        end
      }
    end
  end
end
