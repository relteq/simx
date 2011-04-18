require 'db/import/vehicle-type'
require 'db/import/network'
require 'db/import/context'

module Aurora
  class Scenario
    include Aurora
    
    def self.create_from_xml scenario_xml, ctx = nil
      scenario = create_with_id scenario_xml["id"] do |sc|
        ctx ||= ImportContext.new sc
        sc.import_xml scenario_xml, ctx
      end
      ctx.do_deferred
      scenario.save_changes ## needed?
      scenario
    end
    
    def import_xml scenario_xml, ctx
      self.name = scenario_xml["name"]

      descs = scenario_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      
      scenario_xml.xpath("settings/VehicleTypes/vtype").each do |vtype_xml|
        ctx.defer do
          VehicleType.create_from_xml vtype_xml, ctx
        end
      end
      
      scenario_xml.xpath("settings/units").each do |units_xml|
        self.units = units_xml.text
      end
      
      scenario_xml.xpath("settings/display").each do |display_xml|
        self.dt = Float(display_xml["dt"])
        self.begin_time = Float(display_xml["timeInitial"] || 0.0)
        self.duration = Float(display_xml["timeMax"] || begin_time) - begin_time
      end

      scenario_xml.xpath("network").each do |network_xml|
        self.network = Network.create_from_xml(network_xml, ctx)
      end
      
      ### profiles, etc.
    end
  end
end
