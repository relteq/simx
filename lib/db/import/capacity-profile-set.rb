require 'db/import/capacity-profile'

module Aurora
  class CapacityProfileSet
    include Aurora
    
    def self.create_from_xml cp_set_xml, ctx
      create_with_id cp_set_xml["id"] do |cp_set|
        cp_set.import_xml cp_set_xml, ctx
        cp_set.network_id = ctx.scenario.network_id
          # since we are creating a new cp set, let's assume the user wants
          # to edit it using the network in this scenario; that can be
          # changed later by the user.
      end
    end

    def import_xml cp_set_xml, ctx
      clear_members
      
      set_name_from cp_set_xml["name"], ctx

      descs = cp_set_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      self.user_id_modifier = ctx.redmine_user_id
      
      cp_set_xml.xpath("capacity").each do |cp_xml|
        ctx.defer do
          CapacityProfile.create_from_xml cp_xml, ctx
        end
      end
    end
  end
end
