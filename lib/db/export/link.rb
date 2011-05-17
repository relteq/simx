module Aurora
  class Link
    def build_xml(xml)
      attrs = {
        :id => id,
        :type => self[:type],
        :lanes => lanes,
        :length => length
      }
      
      attrs[:name] = name unless name.empty?

      xml.link(attrs) {
        xml.description description unless description.empty?
        xml.begin(:node_id => begin_node.id)
        xml.end(:node_id => end_node.id)
        xml << fd
        xml.dynamics(:type => dynamics)
        xml.qmax { xml.text qmax }
      }
    end
  end
end
