module Aurora
  # corresponds to <density> element
  class InitialCondition
    include Aurora
    
    def self.create_from_xml ic_xml, ctx
      create_with_id ic_xml["id"] do |ic|
        ic.import_xml ic_xml, ctx
        ic.ic_set = ctx.scenario.ic_set
      end
    end
    
    def import_xml ic_xml, ctx
      self.link_id    = ctx.get_link_id(ic_xml["link_id"])
      self.density    = ic_xml.text
    end
  end
end
