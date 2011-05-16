module Aurora
  class Sensor
    def build_xml(xml)
      attrs = {
        :id             => id,
        :type           => self[:type],
        :display_lat    => display_lat,
        :display_lng    => display_lng,
        :length         => length,
        :offset_in_link => offset,
        :data_id        => data_id,
        :link_type      => link_type,
        :vds            => vds,
        :hwy_name       => hwy_name,
        :hwy_dir        => hwy_dir,
        :postmile       => postmile,
        :lanes          => lanes
      }
      
      xml.sensor(attrs) {
        xml.description description unless description.empty?
        
        xml.position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          point_attrs[:elevation] = elevation if elevation != 0
          xml.point point_attrs
        }
        
        xml.links {
          xml.text link.id
        }
      }
    end
  end
end
