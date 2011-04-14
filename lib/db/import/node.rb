require 'db/model/node'

require 'db/import/network'
require 'db/import/split-ratio-profile'

module Aurora
  class Node
    include Aurora
    
    def self.from_xml node_xml, scenario
      node = import_network_element_id(node_xml["id"], scenario.network)
      node.import_xml node_xml, scenario
      node.save
      node
    end
    
    def import_xml node_xml, scenario
      scenario.node_id_for_xml_id[node_xml["id"]] = id
      
      ### subnetwork_id -- add_node can do this

      self.name = node_xml["name"]
      self.type = node_xml["type"]
      
      descs = node_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      node_xml.xpath("position/point").each do |point_xml|
        self.lat = Float(point_xml["lat"])
        self.lng = Float(point_xml["lng"])
        if point_xml["elevation"]
          self.elevation = Float(point_xml["elevation"])
        end
      end
      
      # Note: we scan the NodeList section before the LinkList section,
      # so store these here for Link#import_xml to use later.
      scenario.output_link_ids_for_node_id[id] =
        node_xml.xpath("outputs/output").map {|xml| xml["link_id"]}
      scenario.input_link_ids_for_node_id[id] =
        node_xml.xpath("inputs/input").map {|xml| xml["link_id"]}
      scenario.weaving_factors_for_node_id[id] =
        node_xml.xpath("inputs/input").map {|xml|
          xml.xpath("weavingfactors").first}
    end
  end
end
