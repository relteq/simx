require 'db/export/node'
require 'db/export/link'
require 'db/export/sensor'

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
        
        lists = [
          ["NodeList", nodes],
          ["LinkList", links],
          ["NetworkList", subnetworks],
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

#          ["ODList/od/PathList/path", routes],
        
        xml << directions_cache
        xml << intersection_cache
      }
    end
  end
end
