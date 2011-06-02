module Aurora
  class Event
    def build_xml(xml)
      attrs = {
        :type => event_type,
        :enabled => enabled,
        :tstamp => time
      }
      
      attrs[:network_id] = network_id if network_id
      attrs[:node_id] = node_id if node_id
      attrs[:link_id] = link_id if link_id
      
      xml.event(attrs) do
        xml << parameters
      end
    end
  end
end
