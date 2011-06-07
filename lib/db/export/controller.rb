module Aurora
  class Controller
    def build_xml(xml)
      attrs = {
        :type => controller_type,
        :usesensors => use_sensors,
        :dt => "%.1f" % dt
      }
      
      attrs[:network_id] = network_id if network_id
      attrs[:node_id] = node_id if node_id
      attrs[:link_id] = link_id if link_id
      
      xml.controller(attrs) do
        xml << parameters
      end
    end
  end
end
