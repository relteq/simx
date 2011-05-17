module Aurora
  class Sensor
    def build_xml(xml)
      attrs = {
        :id             => id,
        :type           => self[:type],
        :display_lat    => display_lat,
        :display_lng    => display_lng,
        :link_type      => link_type
      }
      
      attrs[:length]         = length   unless length == 0
      attrs[:offset_in_link] = offset   unless offset == 0
      attrs[:data_id]        = data_id  unless !data_id or data_id.empty?
      attrs[:vds]            = vds      unless !vds or vds.empty?
      attrs[:hwy_name]       = hwy_name unless !hwy_name or hwy_name.empty?
      attrs[:hwy_dir]        = hwy_dir  unless !hwy_dir or hwy_dir.empty?
      attrs[:postmile]       = postmile unless postmile == 0
      attrs[:lanes]          = lanes    unless !lanes or lanes.empty?
      
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
        
        xml.links {
          xml.text link.id
        }
      }
    end
  end
end
