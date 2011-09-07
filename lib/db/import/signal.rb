require 'db/import/phase'

module Aurora
  class Signal
    include Aurora
    
    def self.create_from_xml signal_xml, ctx, network
      create do |signal|
        signal.network = network
        signal.import_xml signal_xml, ctx
      end
    end
    
    def import_xml signal_xml, ctx
#p signal_xml
#puts '---'
#p signal_xml["node_id"]
#puts '---'
#p ctx.get_node_id(signal_xml["node_id"])
#puts '---'
      update(:node_id => ctx.get_node_id(signal_xml["node_id"]))

      ctx.defer do
        signal_xml.xpath("phase").each do |phase_xml|
          Phase.create_from_xml(phase_xml, ctx, self)
        end
      end
    end
  end
end

