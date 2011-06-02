module Aurora
  class Controller
    include Aurora
    
    def self.create_from_xml ctrl_xml, ctx
      create_with_id ctrl_xml["id"] do |ctrl|
        ctrl.import_xml ctrl_xml, ctx
        ctrl.controller_set = ctx.scenario.controller_set
      end
    end
    
    def import_xml ctrl_xml, ctx
      self.controller_type = ctrl_xml["type"]
      self.dt              = Float(ctrl_xml["dt"])
      self.use_sensors     = import_boolean(ctrl_xml["usesensors"], false)
      
      fudge1 = "\n    " ## a hack until we parse the xml into the database
      fudge2 = "\n      "
      self.parameters = fudge2 +
        ctrl_xml.xpath("*").map {|xml| xml.to_s}.join(fudge2) + fudge1
      
      if /\S/ === ctrl_xml["network_id"]
        self.type = 'NetworkController'
        ctx.defer do
          self.update(:network_id => ctx.get_network_id(ctrl_xml["network_id"]))
        end
      end

      if /\S/ === ctrl_xml["node_id"]
        self.type = 'NodeController'
        ctx.defer do
          self.update(:node_id => ctx.get_node_id(ctrl_xml["node_id"]))
        end
      end

      if /\S/ === ctrl_xml["link_id"]
        self.type = 'LinkController'
        ctx.defer do
          self.update(:link_id => ctx.get_link_id(ctrl_xml["link_id"]))
        end
      end
    end
  end
end
