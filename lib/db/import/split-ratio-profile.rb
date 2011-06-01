module Aurora
  # corresponds to <splitratios> element, plus children <srm> elements
  class SplitRatioProfile
    include Aurora
    
    def self.create_from_xml srp_xml, ctx
      create_with_id srp_xml["id"] do |srp|
        srp.import_xml srp_xml, ctx
        srp.split_ratio_profile_set = ctx.scenario.split_ratio_profile_set
      end
    end
    
    def import_xml srp_xml, ctx
      self.dt         = Float(srp_xml["dt"])
      self.start_time = Float(srp_xml["start_time"] || 0)
      self.node_id    = ctx.get_node_id(srp_xml["node_id"])
      
      fudge1 = "\n    " ## a hack until we parse the xml into the database
      fudge2 = "\n      "
      self.profile = fudge2 +
        srp_xml.xpath("srm").map {|srm_xml| srm_xml.to_s}.join(fudge2) + fudge1
    end
  end
end
