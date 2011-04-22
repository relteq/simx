module Aurora
  class Controller
    include Aurora
    
    def self.create_from_xml ctrl_xml, ctx
      create_with_id ctrl_xml["id"] do |ctrl|
        ctrl.import_xml ctrl_xml, ctx
        ctrl.ctrl_set = ctx.scenario.ctrl_set
      end
    end
    
    def import_xml ctrl_xml, ctx
      self.link_id    = ctx.get_link_id(ctrl_xml["link_id"])
    end
  end
end
