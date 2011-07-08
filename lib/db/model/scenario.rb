module Aurora
  class Scenario
    many_to_one :project

    many_to_one :network, :key => :network_id
    
    many_to_one :split_ratio_profile_set,   :class => SplitRatioProfileSet
    many_to_one :capacity_profile_set,      :class => CapacityProfileSet
    many_to_one :demand_profile_set,        :class => DemandProfileSet
    many_to_one :initial_condition_set,     :class => InitialConditionSet
    many_to_one :event_set,                 :class => EventSet
    many_to_one :controller_set,            :class => ControllerSet

    one_to_many :vehicle_types

    # This has to save or else copied vehicle types cannot
    # be attached.
    def shallow_copy
      s = Scenario.new
      s.columns.each do |c|
        s.set(c => self[c]) if c != :id
      end
      s.save

      vehicle_types.each do |vtype|
        copy = vtype.copy
        copy.scenario_id = s.id
        copy.save
      end
      return s
    end

    def clear_members
      vehicle_types.each do |vtype|
        vtype.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
