require 'db/export/split_ratio_profile'

module Aurora
  class SplitRatioProfileSet
    def build_xml(xml)
      xml.SplitRatioProfileSet(:id => id, :name => name) {
        xml.description description
        
        srps.each do |srp|
          srp.build_xml(xml)
        end
      }
    end
  end
end
