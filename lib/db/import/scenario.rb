require 'db/import/model'
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
    
    class Dummy
      PARTS = [
        :id,
        :project_id,
        :network,
        :split_ratio_profile_set,
        :capacity_profile_set,
        :demand_profile_set,
        :initial_condition_set,
        :event_set,
        :controller_set
      ]

      attr_accessor *PARTS

      def initialize scenario = nil
        @id = 0
        
        if scenario
          PARTS.each do |part|
            self.send "#{part}=", scenario.send(part)
          end
        end
      end
      
      def save
        # no-op
      end
    end

    # If the scenario has id=0, it will not be added to the database, but
    # its network, profiles, etc will. In that case, this method returns
    # a Dummy instead of a real scenario.
    def self.create_from_xml scenario_xml, ctx_options = {} 
      scenario_is_just_packaging = (
        scenario_xml["id"] =~ /\A\s*(0+|null)\s*\z/i
      )
      
      if scenario_is_just_packaging
        sc0 = Scenario[0]
        sc0.destroy if sc0
      end
      
      ctx_options[:scenario_is_just_packaging] =
        scenario_is_just_packaging

      ctx = nil
      scenario = create_with_id scenario_xml["id"] do |sc|
        ctx = ImportContext.new sc, ctx_options
        sc.import_xml scenario_xml, ctx
      end
      
      ctx.do_deferred
      scenario.save_changes
      
      if scenario_is_just_packaging
        sc0 = Scenario[0]
        sc0.destroy if sc0

        Dummy.new(scenario)
      else
        scenario
      end
    end
    
    def import_xml scenario_xml, ctx
      unless ctx.scenario_is_just_packaging
        clear_members
      
        self.user_id_creator = ctx.redmine_user_id
        self.user_id_modifier = ctx.redmine_user_id

        set_name_from scenario_xml["name"], ctx

        descs = scenario_xml.xpath("description").map {|desc_xml| desc_xml.text}
        self.description = descs.join("\n")

        scenario_xml.xpath("settings/VehicleTypes/vtype").each do |vtype_xml|
          ctx.defer do
            VehicleType.create_from_xml vtype_xml, ctx
          end
        end

        scenario_xml.xpath("settings/display").each do |display_xml|
          self.dt = Float(display_xml["dt"])
          self.begin_time = Float(display_xml["timeInitial"] || 0.0)
          self.duration =
            Float(display_xml["timeMax"] || begin_time) - begin_time
        end
      end

      scenario_xml.xpath("settings/units").each do |units_xml|
        self.units = units_xml.text
      end

      [split_ratio_profile_set, capacity_profile_set, demand_profile_set,
       initial_condition_set, event_set, controller_set].each do |set|
        set.clear_members if set
          # in case the network elts they refer to are no longer present
      end

      scenario_xml.xpath("network").each do |network_xml|
        self.network = Network.create_from_xml(network_xml, ctx)
      end
      
      scenario_xml.xpath("SplitRatioProfileSet").each do |srp_set_xml|
        self.split_ratio_profile_set = 
          SplitRatioProfileSet.create_from_xml(srp_set_xml, ctx)
      end

      scenario_xml.xpath("CapacityProfileSet").each do |cp_set_xml|
        self.capacity_profile_set = 
          CapacityProfileSet.create_from_xml(cp_set_xml, ctx)
      end

      scenario_xml.xpath("DemandProfileSet").each do |dp_set_xml|
        self.demand_profile_set = 
          DemandProfileSet.create_from_xml(dp_set_xml, ctx)
      end

      scenario_xml.xpath("InitialDensityProfile").each do |ic_set_xml|
        self.initial_condition_set = 
          InitialConditionSet.create_from_xml(ic_set_xml, ctx)
      end

      scenario_xml.xpath("EventSet").each do |event_set_xml|
        self.event_set = EventSet.create_from_xml(event_set_xml, ctx)
      end

      scenario_xml.xpath("ControllerSet").each do |ctrl_set_xml|
        self.controller_set = ControllerSet.create_from_xml(ctrl_set_xml, ctx)
      end
    end
  end
end
