module Aurora
  class Event
    include Aurora
    
    def self.create_from_xml event_xml, ctx
      create_with_id event_xml["id"] do |event|
        event.import_xml event_xml, ctx
        event.event_set = ctx.scenario.event_set
      end
    end
    
    def import_xml event_xml, ctx
      self.event_type  = event_xml["type"]
      self.time        = Float(event_xml["tstamp"])
      self.enabled     = import_boolean(event_xml["enabled"])
      
      fudge1 = "\n    " ## a hack until we parse the xml into the database
      fudge2 = "\n      "
      self.parameters = fudge2 +
        event_xml.xpath("*").map {|xml| xml.to_s}.join(fudge2) + fudge1
      
      if /\S/ === event_xml["network_id"]
        self.type = 'NetworkEvent'
        ctx.defer do
          self.update(:network_id => ctx.get_network_id(event_xml["network_id"]))
        end
      end

      if /\S/ === event_xml["node_id"]
        self.type = 'NodeEvent'
        ctx.defer do
          self.update(:node_id => ctx.get_node_id(event_xml["node_id"]))
        end
      end

      if /\S/ === event_xml["link_id"]
        self.type = 'LinkEvent'
        ctx.defer do
          self.update(:link_id => ctx.get_link_id(event_xml["link_id"]))
        end
      end
    end
  end
end
