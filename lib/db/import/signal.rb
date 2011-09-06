module Aurora
  class Signal
    include Aurora
    
    def self.create_from_xml signal_xml, ctx, parent
      create_with_id signal_xml["id"], parent.id do |signal|
      end
    end
    
    def import_xml signal_xml, ctx
    end
  end
end

