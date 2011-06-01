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
        ctx.defer do
          ne = NetworkEvent.create do |network_event|
            network_event.event_id = id
            network_event.network_family_id =
              ctx.get_network_id(event_xml["network_id"])
          end
          self.update(:network_id => ne.network_family_id)
        end
        self.type = 'NetworkEvent'
      end

      if /\S/ === event_xml["node_id"]
        ctx.defer do
          ne = NodeEvent.create do |node_event|
            node_event.event_id = id
            node_event.node_family_id = ctx.get_node_id(event_xml["node_id"])
          end
          self.update(:node_id => ne.node_family_id)
        end
        self.type = 'NodeEvent'
      end

      if /\S/ === event_xml["link_id"]
        ctx.defer do
          le = LinkEvent.create do |link_event|
            link_event.event_id = id
            link_event.link_family_id = ctx.get_link_id(event_xml["link_id"])
          end
          self.update(:link_id => le.link_family_id)
        end
        self.type = 'LinkEvent'
      end
    end
  end
end
