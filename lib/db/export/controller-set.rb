require 'db/export/controller'

module Aurora
  class ControllerSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless name.empty?
      
      xml.ControllerSet(attrs) {
        xml.description description unless description.empty?
        
        controllers.each do |controller|
          controller.build_xml(xml)
        end
      }
    end
  end
end
