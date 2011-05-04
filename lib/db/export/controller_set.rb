require 'db/export/controller'

module Aurora
  class ControllerSet
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
      xml.ControllerSet(:id => self.id) {
        self.controllers.each do |c|
          c.to_xml(xml)
        end
      }
    end
  end
end
