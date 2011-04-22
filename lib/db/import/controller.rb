module Aurora
  class Controller
    include Aurora
    
    def self.create_from_xml ctrl_xml, ctx
      create_with_id ctrl_xml["id"] do |ctrl|
        ctrl.import_xml ctrl_xml, ctx
        ctrl.controller_set = ctx.scenario.ctrl_set
      end
    end
    
    def import_xml ctrl_xml, ctx
      self.type         = ctrl_xml["type"]
      self.dt           = Float(ctrl_xml["dt"])
      self.use_sensors  = import_boolean(ctrl_xml["usesensors"], false)
      
      ## should we pull some of this out so it can be seen in rails?
      self.parameters = ctrl_xml.xpath("*").map {|xml| xml.to_s}.join("\n")
      
      if /\S/ === ctrl_xml["network_id"]
        ctx.defer do
          NetworkController.create do |network_ctrl|
            network_ctrl.controller_id = id
            network_ctrl.network_family_id =
              ctx.get_network_id(ctrl_xml["network_id"])
          end
        end
      end

      if /\S/ === ctrl_xml["node_id"]
        ctx.defer do
          NodeController.create do |node_ctrl|
            node_ctrl.controller_id = id
            node_ctrl.node_family_id = ctx.get_node_id(ctrl_xml["node_id"])
          end
        end
      end

      if /\S/ === ctrl_xml["link_id"]
        ctx.defer do
          LinkController.create do |link_ctrl|
            link_ctrl.controller_id = id
            link_ctrl.link_family_id = ctx.get_link_id(ctrl_xml["link_id"])
          end
        end
      end
    end
  end
end
