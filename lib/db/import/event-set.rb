require 'db/import/event'

module Aurora
  class EventSet
    include Aurora
    
    def self.create_from_xml event_set_xml, ctx
      create_with_id event_set_xml["id"] do |event_set|
        event_set.import_xml event_set_xml, ctx
        event_set.network_id = ctx.scenario.network_id
          # since we are creating a new event set, let's assume the user wants
          # to edit it using the network in this scenario; that can be
          # changed later by the user.
      end
    end

    def import_xml event_set_xml, ctx
      clear_members
      
      set_name_from event_set_xml["name"], ctx

      descs = event_set_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      
      event_set_xml.xpath("event").each do |event_xml|
        ctx.defer do
          Event.create_from_xml event_xml, ctx
        end
      end
    end
  end
end
