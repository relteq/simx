module Aurora
  class Link
    def build_xml(xml)
      attrs = {
        :id => id,
        :type => type_link,
        :lanes => "%.1f" % lanes,
        :length => "%d" % length
      }
      
      attrs[:name] = name unless !name or name.empty?
      attrs[:road_name] = road_name unless !road_name or road_name.empty?
      attrs[:lane_offset] = lane_offset unless !lane_offset

      xml.link(attrs) {
        xml.description description unless !description or description.empty?
        xml.begin(:node_id => begin_node.id)
        xml.end(:node_id => end_node.id)
        xml << fd
        xml.dynamics(:type => dynamics)
        xml.qmax { xml.text("%.4f" % qmax) }
      }
    end
  end
end
