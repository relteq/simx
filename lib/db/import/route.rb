module Aurora
  class Route
    include Aurora
    
    def self.create_from_xml route_xml, ctx, parent
      create_with_id route_xml["id"], parent.id do |route|
        if route.id
          RouteFamily[route.id] or
            RouteFamily.create {|rf| rf.id = route.id}
        else
          rf = route.route_family = RouteFamily.create
          ctx.route_family_id_for_xml_id[route_xml["id"]] = rf.id
        end
        
        route.network = parent
        route.import_xml route_xml, ctx
      end
    end
    
    def import_xml route_xml, ctx
      set_name_from route_xml["name"], ctx
      
      ctx.defer do # the route doesn't exist yet
        self.class.db[:route_links].where(
          :network_id => network_id,
          :route_id   => id
        ).delete
        
        link_xml_ids = route_xml.text.split(",").map{|s|s.strip}
        link_xml_ids.each_with_index do |link_xml_id, order|
          self.class.db[:route_links] << {
            :network_id => network_id,
            :route_id   => id,
            :link_id    => ctx.get_link_id(link_xml_id),
            :ordinal    => order
          }
        end
      end
    end
  end
end
