require 'db/import/vehicle-type'
require 'db/import/network'
require 'db/import/context'
require 'db/import/split-ratio-profile-set'
require 'db/import/capacity-profile-set'
require 'db/import/demand-profile-set'
require 'db/import/initial-condition-set'
require 'db/import/event-set'
require 'db/import/controller-set'

module Aurora
  class Scenario
    include Aurora
    
    def self.create_from_xml scenario_xml, ctx = nil
      scenario = create_with_id scenario_xml["id"] do |sc|
        prev_scenario = Scenario[:id => sc.id]
        prev_scenario_state = prev_scenario ? prev_scenario.values : {}
        raise if prev_scenario ## for now, this mode is not handled
        
        ctx ||= ImportContext.new sc, prev_scenario_state
        sc.import_xml scenario_xml, ctx
      end
      
      ctx.do_deferred
      scenario.save_changes ## needed?
      scenario
    end
    
    def import_xml scenario_xml, ctx
      set_name_from scenario_xml["name"], ctx

      descs = scenario_xml.xpath("description").map {|desc_xml| desc_xml.text}
      self.description = descs.join("\n")
      
      scenario_xml.xpath("settings/VehicleTypes/vtype").each do |vtype_xml|
        ctx.defer do
          ##vehicle_types.each do |vtype|
          ##  vtype.destroy
          ##end
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
      
      scenario_xml.xpath("SplitRatioProfileSet").each do |srp_set_xml|
        self.srp_set = SplitRatioProfileSet.create_from_xml(srp_set_xml, ctx)
      end

      scenario_xml.xpath("CapacityProfileSet").each do |cp_set_xml|
        self.cp_set = CapacityProfileSet.create_from_xml(cp_set_xml, ctx)
      end

      scenario_xml.xpath("DemandProfileSet").each do |dp_set_xml|
        self.dp_set = DemandProfileSet.create_from_xml(dp_set_xml, ctx)
      end

      scenario_xml.xpath("InitialDensityProfile").each do |ic_set_xml|
        self.ic_set = InitialConditionSet.create_from_xml(ic_set_xml, ctx)
      end

      scenario_xml.xpath("EventSet").each do |event_set_xml|
        self.event_set = EventSet.create_from_xml(event_set_xml, ctx)
      end

      scenario_xml.xpath("ControllerSet").each do |ctrl_set_xml|
        self.ctrl_set = ControllerSet.create_from_xml(ctrl_set_xml, ctx)
      end

      ## what do we do if there are existing network, srp_set, vtypes,
      ## etc.? Delete them?
    end
  end
end
