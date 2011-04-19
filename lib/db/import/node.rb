module Aurora
  class Node
    include Aurora
    
    def self.create_from_xml node_xml, ctx, parent
      create_with_id node_xml["id"] do |node|
        if node.id
          NodeFamily[node.id] or
            NodeFamily.create {|nf| nf.id = node.id}
        else
          nf = node.node_family = NodeFamily.create
          ctx.node_family_id_for_xml_id[node_xml["id"]] = nf.id
        end
        
        node.parent = parent
        node.import_xml node_xml, ctx
      end
    end
    
    def import_xml node_xml, ctx
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
      node_xml.xpath("outputs/output").each_with_index do |xml, ord|
        ctx.begin_for_link_xml_id[ xml["link_id"] ] = [self, ord]
      end
      
      wf = node_xml.xpath("weavingfactors").first
      node_xml.xpath("inputs/input").each_with_index do |xml, ord|
        ctx.end_for_link_xml_id[ xml["link_id"] ] = [self, ord, wf]
      end
    end
  end
end
