module Aurora
  class Link
    include Aurora
    
    def self.create_from_xml link_xml, ctx, parent
      create_with_id link_xml["id"] do |link|
        if link.id
          LinkFamily[link.id] or
            raise "xml specified nonexistent link_id: #{link.id}" ##
        else
          lf = link.link_family = LinkFamily.create
          ctx.link_family_id_for_xml_id[link_xml["id"]] = lf.id
        end
        
        link.parent = parent
        link.import_xml link_xml, ctx
      end
    end
    
    def import_xml link_xml, ctx
      self.name = link_xml["name"]

      descs = link_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      self.lanes = Integer(link_xml["lanes"])
      self.length = ctx.import_length(link_xml["length"])
      self.type = link_xml["type"]
      
      link_xml.xpath("fd").each do |fd_xml|
        # just store the xml in the column for now
        self.fd = fd_xml.to_s
      end
      link_xml.xpath("qmax").each do |qmax_xml|
        self.qmax = Float(qmax_xml.text)
      end
      link_xml.xpath("dynamics").each do |dynamics_xml|
        self.dynamics = dynamics_xml["type"]
      end

      begin_id_xml  = link_xml.xpath("begin").first["node_id"]
      end_id_xml    = link_xml.xpath("end").first["node_id"]

      self.begin_node, self.begin_order =
        ctx.begin_for_link_xml_id[link_xml["id"]]

      self.end_node, self.end_order, self.weaving_factors =
        ctx.end_for_link_xml_id[link_xml["id"]]
    end
  end
end
