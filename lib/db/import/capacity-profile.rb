module Aurora
  # corresponds to <capacity> element
  class CapacityProfile
    include Aurora
    
    def self.create_from_xml cp_xml, ctx
      create_with_id cp_xml["id"] do |cp|
        cp.import_xml cp_xml, ctx
        cp.cp_set = ctx.scenario.cp_set
      end
    end
    
    def import_xml cp_xml, ctx
      self.dt         = Float(cp_xml["dt"])
      self.start_time = Float(cp_xml["start_time"] || 0)
      self.link_id    = ctx.get_link_id(cp_xml["link_id"])
      self.profile    = cp_xml.text
    end
  end
end
