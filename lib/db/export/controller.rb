module Aurora
  class Controller
    def build_xml(xml)
      attrs = {
        :type => self[:type],
        :usesensors => use_sensors,
        :dt => dt
      }
      
      case
      when network_controller
        attrs[:network_id] = network_controller.network_family_id
      when node_controller
        attrs[:node_id] = node_controller.node_family_id
      when link_controller
        attrs[:link_id] = link_controller.link_family_id
      end
      
      xml.controller(attrs) do
        xml << parameters
      end
    end
  end
end
