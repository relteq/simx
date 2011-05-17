require 'db/export/controller'

module Aurora
  class ControllerSet
    def build_xml(xml)
      attrs = {:id => id}
      attrs[:name] = name unless !name or name.empty?
      
      xml.ControllerSet(attrs) {
        xml.description description unless !description or description.empty?
        
        controllers.each do |controller|
          controller.build_xml(xml)
        end
      }
    end
  end
end
