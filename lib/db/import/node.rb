require 'db/import/network'

module Aurora
  class Node
    include Aurora
    
    def self.create_from_xml node_xml, ctx, parent
      create_with_id node_xml["id"] do |nd|
        if nd.id
          NodeFamily[nd.id] or
            raise "xml specified nonexistent node_id: #{nd.id}" ##
        else
          nf = nd.node_family = NodeFamily.create
          ctx.node_family_id_for_xml_id[node_xml["id"]] = nf.id
        end
        
        nd.parent = parent
        nd.import_xml node_xml, ctx
      end
    end
    
    def import_xml node_xml, scenario
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
