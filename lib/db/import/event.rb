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
      self.type     = event_xml["type"]
      self.time     = Float(event_xml["tstamp"])
      self.enabled  = import_boolean(event_xml["enabled"])
      
      self.parameters = event_xml.xpath("*").map {|xml| xml.to_s}.join("\n")
      
      if /\S/ === event_xml["network_id"]
        ctx.defer do
          NetworkEvent.create do |network_event|
            network_event.event_id = id
            network_event.network_family_id =
              ctx.get_network_id(event_xml["network_id"])
          end
        end
      end

      if /\S/ === event_xml["node_id"]
        ctx.defer do
          NodeEvent.create do |node_event|
            node_event.event_id = id
            node_event.node_family_id = ctx.get_node_id(event_xml["node_id"])
          end
        end
      end

      if /\S/ === event_xml["link_id"]
        ctx.defer do
          LinkEvent.create do |link_event|
            link_event.event_id = id
            link_event.link_family_id = ctx.get_link_id(event_xml["link_id"])
          end
        end
      end
    end
  end
end
