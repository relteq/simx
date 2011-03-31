require 'db/model/network'

require 'db/import/node'
require 'db/import/link'

module Aurora
  class Network
    def self.import_xml network_xml
      network = create
      
      descs = network_xml.xpath("description").map {|desc| desc.text}
      network.description = descs.join("\n")

      network_xml.xpath("position/point").each do |point_xml|
        network.x = point_xml["x"]
        network.y = point_xml["y"]
        network.z = point_xml["z"]
      end
      
      network.name        = network_xml["name"]
      network.controlled  = (network_xml["controlled"] == "true") ##?
      network.top         = (network_xml["top"] == "true") ##?
      network.tp          = Float(network_xml["tp"])
      
      ## do we do anything special with id="-1"?
      
      network_xml.xpath("NodeList/node").each do |node_xml|
        node = Node.import_xml(node_xml)
        network.add_node node
      end

      network_xml.xpath("LinkList/link").each do |link_xml|
        link = Link.import_xml(link_xml)
        network.add_link link
      end
      
      ## caches (dir and int)
      ## clear out obsolete entries

      network.save
      network
    end
  end
end
