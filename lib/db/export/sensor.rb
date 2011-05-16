module Aurora
  class Sensor
    def build_xml(xml)
      xml.sensor(:id => id, :type => self[:type]) {
        xml.description description unless description.empty?
        xml.position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          point_attrs[:elevation] = elevation if elevation != 0
          xml.point point_attrs
        }
      }
    end
  end
end
