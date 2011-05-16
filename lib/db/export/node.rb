require 'db/export/event'

module Aurora
  class Node
    def build_xml(xml)
      xml.node(:id => id, :name => name, :type => self[:type]) {
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
