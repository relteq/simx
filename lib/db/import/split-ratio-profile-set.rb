require 'db/import/split-ratio-profile'

module Aurora
  class SplitRatioProfileSet
    include Aurora
    
    def self.create_from_xml srp_set_xml, ctx
      create_with_id srp_set_xml["id"] do |srp_set|
        srp_set.import_xml srp_set_xml, ctx
        srp_set.network_id = ctx.scenario.network_id
          # since we are creating a new srp set, let's assume the user wants
          # to edit it using the network in this scenario; that can be
          # changed later by the user.
      end
    end

    def import_xml srp_set_xml, ctx
      clear_members
      
      set_name_from srp_set_xml["name"], ctx

      descs = srp_set_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      self.user_id_modifier = ctx.redmine_user_id
      
      srp_set_xml.xpath("splitratios").each do |srp_xml|
        ctx.defer do
          SplitRatioProfile.create_from_xml srp_xml, ctx
        end
      end
    end
  end
end
