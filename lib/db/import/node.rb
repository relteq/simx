require 'db/model/node'

require 'db/import/network'
require 'db/import/split-ratio-profile'

module Aurora
  class Node
    def self.from_xml node_xml, scenario
      node = create
      node.import_xml node_xml, scenario
      node.save
      node
    end
    
    def import_xml node_xml, scenario
      self.name = node_xml["name"]
      self.type = node_xml["type"]
      
      descs = node_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      node_xml.xpath("postmile").each do |postmile|
        self.postmile = Float(postmile.text)
        ## warn on multiple assignment in this and similar cases
      end

      node_xml.xpath("position/point").each do |point_xml|
        self.lat = point_xml["lat"]
        self.lng = point_xml["lng"]
        self.elevation = point_xml["elevation"] if point_xml["elevation"]
      end
      
      node_xml.xpath("splitratios").each do |splitratios_xml|
        srp = SplitRatioProfile.from_xml(splitratios_xml, scenario)
        add_split_ratio_profile srp
      end
      
      ## outputs and inputs, not for topology but for split, weaving
    end
  end
end
