require 'db/model/node'

require 'db/import/network'
require 'db/import/split-ratio-profile'

module Aurora
  class Node
    def self.import_xml node_xml
      node = create
      
      node.name = node_xml["name"]
      node.type = node_xml["type"]
      
      descs = node_xml.xpath("description").map {|desc| desc.text}
      node.description = descs.join("\n")
      
      node_xml.xpath("postmile").each do |postmile|
        node.postmile = Float(postmile.text)
        ## warn on multiple assignment in this and similar cases
      end

      node_xml.xpath("position/point").each do |point_xml|
        node.x = point_xml["x"]
        node.y = point_xml["y"]
        node.z = point_xml["z"]
      end
      
      node_xml.xpath("splitratios").each do |splitratios_xml|
        srp = SplitRatioProfile.import_xml(splitratios_xml)
        node.add_split_ratio_profile srp
      end
      
      ## outputs and inputs, not for topology but for split, weaving
      
      node.save
      node
    end
  end
end
