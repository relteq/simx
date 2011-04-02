require 'db/model/network'

require 'db/import/node'
require 'db/import/link'

module Aurora
  class Network
    def self.from_xml network_xml, scenario
      network = create
      network.import_xml network_xml, scenario
      network.save
      network
    end
    
    def import_xml network_xml, scenario
      scenario.network_id_for_xml_id[network_xml["id"]] = id

      descs = network_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")

      network_xml.xpath("position/point").each do |point_xml|
        self.lat = point_xml["lat"]
        self.lng = point_xml["lng"]
        self.elevation = point_xml["elevation"] if point_xml["elevation"]
      end
      
      self.name        = network_xml["name"]
      self.controlled  = (network_xml["controlled"] == "true") ##?
      self.top         = (network_xml["top"] == "true") ##?
      self.dt          = Float(network_xml["dt"])
      
      ## do we do anything special with id="-1"?
      
      network_xml.xpath("NodeList/node").each do |node_xml|
        node = Node.from_xml(node_xml, scenario)
        add_node node
      end

      network_xml.xpath("LinkList/link").each do |link_xml|
        link = Link.from_xml(link_xml, scenario)
        add_link link
      end
      
      ## caches (dir and int)
      ## ignore obsolete entries
    end
  end
end
