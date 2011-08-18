module Aurora
  class Link
    include Aurora
    
    def self.create_from_xml link_xml, ctx, parent
      create_with_id link_xml["id"], parent.id do |link|
        if link.id
          LinkFamily[link.id] or
            LinkFamily.create {|lf| lf.id = link.id}
        else
          lf = link.link_family = LinkFamily.create
          ctx.link_family_id_for_xml_id[link_xml["id"]] = lf.id
        end
        
        link.network = parent
        link.import_xml link_xml, ctx
      end
    end
    
    def import_xml link_xml, ctx
      set_name_from link_xml["name"], ctx

      descs = link_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      self.lanes = Float(link_xml["lanes"]) # Fractional lanes allowed.s
      self.length = ctx.import_length(link_xml["length"])
      self.type_link = link_xml["type"]
      self.road_name = link_xml["road_name"] if link_xml["road_name"]
      self.lane_offset = link_xml["lane_offset"].to_i if link_xml["lane_offset"]
      
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

      begin_stuff = ctx.begin_for_link_xml_id[link_xml["id"]]
      end_stuff = ctx.end_for_link_xml_id[link_xml["id"]]
      
      if begin_stuff
        self.begin_node, self.begin_order = begin_stuff
      
      else
        link_xml.xpath("begin").each do |begin_xml|
          b_node = ctx.node_for_xml_id[ begin_xml["node_id"] ]
          
          if b_node
            if not b_node.type_node == "T"
              raise ImportError, "begin node for link #{link_xml["id"]} " +
                "has no output to the link."
            end
          
          else
            raise ImportError, "begin node for link #{link_xml["id"]} " +
              "is missing."
          end
          
          self.begin_node = b_node
          break
        end
      end

      if end_stuff
        self.end_node, self.end_order, self.weaving_factors = end_stuff
      
      else
        link_xml.xpath("end").each do |end_xml|
          e_node = ctx.node_for_xml_id[ end_xml["node_id"] ]
          
          if e_node
            if not e_node.type_node == "T"
              raise ImportError, "end node for link #{link_xml["id"]} " +
                "has no input from the link."
            end
            
          else
            raise ImportError, "end node for link #{link_xml["id"]} " +
              "is missing."
          end
          
          self.end_node = e_node
          break
        end
      end
    end
  end
end
