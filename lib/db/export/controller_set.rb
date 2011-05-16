require 'db/export/controller'

module Aurora
  class ControllerSet
    def build_xml(xml)
      xml.ControllerSet(:id => id, :name => name) {
        xml.description description
        
        controllers.each do |controller|
          controller.build_xml(xml)
        end
      }
    end
  end
end
