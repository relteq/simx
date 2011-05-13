require 'db/import/demand-profile'

module Aurora
  class DemandProfileSet
    include Aurora
    
    def self.create_from_xml dp_set_xml, ctx
      create_with_id dp_set_xml["id"] do |dp_set|
        dp_set.import_xml dp_set_xml, ctx
        dp_set.network_id = ctx.scenario.tln_id
          # since we are creating a new dp set, let's assume the user wants
          # to edit it using the network in this scenario; that can be
          # changed later by the user.
      end
    end

    def import_xml dp_set_xml, ctx
      clear_members
      
      set_name_from dp_set_xml["name"], ctx

      descs = dp_set_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      
      dp_set_xml.xpath("demand").each do |dp_xml|
        ctx.defer do
          DemandProfile.create_from_xml dp_xml, ctx
        end
      end
    end
  end
end
