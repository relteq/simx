require 'db/import/controller'

module Aurora
  class ControllerSet
    include Aurora
    
    def self.create_from_xml ctrl_set_xml, ctx
      create_with_id ctrl_set_xml["id"] do |ctrl_set|
        ctrl_set.import_xml ctrl_set_xml, ctx
        ctrl_set.network_id = ctx.scenario.tln_id
          # since we are creating a new ctrl set, let's assume the user wants
          # to edit it using the network in this scenario; that can be
          # changed later by the user.
      end
    end

    def import_xml ctrl_set_xml, ctx
      set_name_from ctrl_set_xml["name"], ctx

      descs = ctrl_set_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      
      ctrl_set_xml.xpath("controller").each do |ctrl_xml|
        ctx.defer do
          Controller.create_from_xml ctrl_xml, ctx
        end
      end
    end
  end
end
