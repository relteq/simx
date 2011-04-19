module Aurora
  class Route
    include Aurora
    
    def self.create_from_xml route_xml, ctx, parent
      create_with_id route_xml["id"] do |route|
        if route.id
          RouteFamily[route.id] or
            raise "xml specified nonexistent route_id: #{route.id}" ##
        else
          lf = route.route_family = RouteFamily.create
          ctx.route_family_id_for_xml_id[route_xml["id"]] = lf.id
        end
        
        route.parent = parent
        route.import_xml route_xml, ctx
      end
    end
    
    def import_xml route_xml, ctx
      self.name = route_xml["name"]
      
      ctx.defer do
        link_xml_ids = route_xml.text.split(/\s*,\s*/).map{|s|s.strip}
        link_xml_ids.each_with_index do |link_xml_id, order|
          self.class.db[:route_links] << {
            :network_id => network_id,
            :route_id   => id,
            :link_id    => ctx.get_link_id(link_xml_id),
            :order      => order
          }
        end
      end
    end
  end
end
