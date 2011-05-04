require 'db/export/split_ratio_profile'

module Aurora
  class SplitRatioProfileSet
    def to_xml(build_object = nil)
      if build_object
        to_xml_with_build_object(build_object)
      else
        builder = Nokogiri::XML::Builder.new do |xml|
          to_xml_with_build_object(xml)
        end
        builder.to_xml
      end 
    end

    def to_xml_with_build_object(xml)
      xml.SplitRatioProfileSet(:id => self.id) {
        profiles = SplitRatioProfile.where(:srp_set_id => self.id)
        profiles.each do |p|
          p.to_xml(xml)
        end
      }
    end
  end
end
