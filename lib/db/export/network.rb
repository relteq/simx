require 'db/export/node'
require 'db/export/link'
require 'db/export/sensor'

module Aurora
  class Network
    def build_xml(xml, db = DB)
      attrs = {
        :id           => id,
        :name         => name,
        :ml_control   => ml_control,
        :q_control    => q_control,
        :dt           => "%.1f" % dt
      }

      xml.network(attrs) {
        xml.description description unless !description or description.empty?
        xml.position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          point_attrs[:elevation] = elevation if elevation != 0
          xml.point point_attrs
        }
        
        lists = [
          ["NodeList", nodes],
          ["LinkList", links],
          ["NetworkList", children],
          ["SensorList", sensors]
        ]
        
        lists.each do |elt_name, models|
          if not models.empty?
            xml.send(elt_name) {
              models.each do |model|
                model.build_xml(xml)
              end
            }
          end
        end
        
        if not routes.empty?
          od_routes = Hash.new do |h, k|
            h[k] = []
          end
            # [begin_node_id, end_node_id] => [ [route,links], ...]
            # where links is sorted by order
          
          routes.each do |route|
            rls =
              db[:route_links].
              filter(:network_id => id, :route_id => route.id).
              order_by(:ordinal)
            
            links = rls.map {|rl|
              Link[:network_id => id, :id => rl[:link_id]]}
            
            begin_node = links.first.end_node
            end_node = links.last.begin_node
            
            od_routes[ [begin_node.id, end_node.id] ] << [route, links]
          end
          
          xml.ODList {
            od_routes.each do |(begin_node_id, end_node_id), routes_with_links|
              xml.od(:begin => begin_node_id, :end => end_node_id) {
                xml.PathList {
                  routes_with_links.each do |route, links|
                    xml.path(:name => route.name, :id => route.id) {
                      xml.text links.map {|link| link.id}.join(",")
                    }
                  end
                }
              }
            end
          }
        end

        xml << directions_cache
        xml << intersection_cache
      }
    end
  end
end
