module Aurora
  class Event
    def build_xml(xml)
      attrs = {
        :type => self[:type],
        :enabled => enabled,
        :tstamp => time
      }
      
      case
      when network_event
        attrs[:network_id] = network_event.network_family_id
      when node_event
        attrs[:node_id] = node_event.node_family_id
      when link_event
        attrs[:link_id] = link_event.link_family_id
      end
      
      xml.event(attrs) do
        xml << parameters
      end
    end
  end
end
