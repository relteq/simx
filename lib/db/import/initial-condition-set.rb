require 'db/import/initial-condition'

module Aurora
  # corresponds to <InitialDensityProfile> element
  class InitialConditionSet
    include Aurora
    
    def self.create_from_xml ic_set_xml, ctx
      create_with_id ic_set_xml["id"] do |ic_set|
        ic_set.import_xml ic_set_xml, ctx
        ic_set.network_id = ctx.scenario.tln_id
          # since we are creating a new ic set, let's assume the user wants
          # to edit it using the network in this scenario; that can be
          # changed later by the user.
      end
    end

    def import_xml ic_set_xml, ctx
      set_name_from ic_set_xml["name"], ctx

      descs = ic_set_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      
      ic_set_xml.xpath("density").each do |ic_xml|
        ctx.defer do
          InitialCondition.create_from_xml ic_xml, ctx
        end
      end
    end
  end
end
