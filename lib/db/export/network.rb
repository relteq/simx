require 'db/export/node'

module Aurora
  class Network
    def build_xml(xml)
      attrs = {
        :id           => id,
        :network_id   => network_id,
        :name         => name,
        :ml_control   => ml_control,
        :q_control    => q_control,
        :dt           => dt
      }

      xml.Network(attrs) {
        xml.description description unless description.empty?
        xml.position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          point_attrs[:elevation] = elevation if elevation != 0
          xml.point point_attrs
        }
        
        if not nodes.empty?
          xml.NodeLList {
            nodes.each do |node|
              node.build_xml(xml)
            end
          }
        end

#          ["NodeList", nodes],
#          ["LinkList", links],
#          ["NetworkList", subnetworks],
#          ["SensorList", sensors]
#
#          ["ODList/od/PathList/path", routes],
        
        xml << directions_cache
        xml << intersection_cache
      }
    end
  end
end
