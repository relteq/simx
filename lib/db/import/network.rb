require 'db/model/network'

require 'db/import/node'
require 'db/import/link'

module Aurora
  class Network
    include Aurora
    
    def self.from_xml network_xml, scenario, parent = nil
      network = import_id(network_xml["id"])
      network.import_xml network_xml, scenario, parent
      network.save
      network
    end
    
    def import_xml network_xml, scenario, parent = nil
      scenario.network_id_for_xml_id[network_xml["id"]] = id

      self.name         = network_xml["name"]

      descs = network_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")

      self.dt           = Float(network_xml["dt"])
      self.ml_control   = import_boolean(network_xml["ml_control"])
      self.q_control    = import_boolean(network_xml["q_control"])

      network_xml.xpath("position/point").each do |point_xml|
        self.lat = Float(point_xml["lat"])
        self.lng = Float(point_xml["lng"])
        if point_xml["elevation"]
          self.elevation = Float(point_xml["elevation"])
        end
      end
            
      network_xml.xpath("NodeList/node").each do |node_xml|
        node = Node.from_xml(node_xml, scenario)
        add_node node
      end

      network_xml.xpath("NodeList/network").each do |subnetwork_xml|
        subnetwork = Network.from_xml(subnetwork_xml, scenario, self)
        add_children subnetwork
      end

      network_xml.xpath("LinkList/link").each do |link_xml|
        link = Link.from_xml(link_xml, scenario)
        add_link link
      end
      
      ## MonitorList, ODList, SensorList
      ## DirectionsCache
      ## IntersectionCache

      ## ignore obsolete entries
    end
  end
end
