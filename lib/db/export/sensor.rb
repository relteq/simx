module Aurora
  class Sensor
    def build_xml(xml)
      attrs = {
        :id             => id,
        :type           => type_sensor,
        :link_type      => link_type
      }
      
      xml.sensor(attrs) {
        xml.description description unless !description or description.empty?
        
        xml.position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          point_attrs[:elevation] = elevation if elevation != 0
          xml.point point_attrs
        }
        
        xml.display_position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          xml.point point_attrs
        }
        
        xml.links {
          xml.text link.id
        }
        
        xml.parameters {
          parameters_xml = Nokogiri.XML(parameters) # col value is xml string
          parameters_xml.xpath("parameters/parameter").each do |parameter_xml|
            xml.parameter(
              :name   => parameter_xml["name"],
              :value  => parameter_xml["value"]
            )
          end
        }
        
        xml.data_sources {
          data_sources_xml = Nokogiri.XML(data_sources)
          data_sources_xml.xpath("data_sources/source").each do |source_xml|
            xml.source(
              :url    => source_xml["url"],
              :dt     => source_xml["dt"],
              :format => source_xml["format"]
            )
          end
        }
      }
    end
  end
end
