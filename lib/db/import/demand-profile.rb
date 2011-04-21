module Aurora
  # corresponds to <demand> element
  class DemandProfile
    include Aurora
    
    def self.create_from_xml dp_xml, ctx
      create_with_id dp_xml["id"] do |dp|
        dp.import_xml dp_xml, ctx
        dp.dp_set = ctx.scenario.dp_set
      end
    end
    
    def import_xml dp_xml, ctx
      self.dt         = Float(dp_xml["dt"])
      self.start_time = Float(dp_xml["start_time"] || 0)
      self.link_id    = ctx.get_link_id(dp_xml["link_id"])
      self.profile    = dp_xml.text
    end
  end
end
