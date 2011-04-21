module Aurora
  class SplitRatioProfile
    include Aurora
    
    def self.create_from_xml srp_xml, ctx
      create_with_id srp_xml["id"] do |srp|
        srp.import_xml srp_xml, ctx
        srp.srp_set = ctx.scenario.srp_set
      end
    end
    
    def import_xml srp_xml, ctx
      self.dt         = Float(srp_xml["dt"])
      self.start_time = Float(srp_xml["start_time"] || 0)
      self.node_id    = ctx.get_node_id(srp_xml["node_id"])
      
      self.profile =
        srp_xml.xpath("srm").map {|srm_xml| srm_xml.to_s}.join("\n")
    end
  end
end

