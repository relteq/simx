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

    def shallow_copy_children
      vehicle_types
    end

    def shallow_copy_parent_field
      :scenario_id
    end

    def deep_copy(db = DB, overrides = {})
      s = shallow_copy(db, overrides)
      s.network = network.shallow_copy
      
      if overrides[:project_id]
        s.network.project_id = overrides[:project_id]
        s.network.save
      end

      n_id = s.network.id
      s.initial_condition_set = initial_condition_set.shallow_copy(db, :network_id => n_id)
      s.split_ratio_profile_set = 
        split_ratio_profile_set.shallow_copy(db, :network_id => n_id)
      s.capacity_profile_set = capacity_profile_set.shallow_copy(db, :network_id => n_id)
      s.demand_profile_set = demand_profile_set.shallow_copy(db, :network_id => n_id)
      s.event_set = event_set.shallow_copy(db, :network_id => n_id)
      s.controller_set = controller_set.shallow_copy(db, :network_id => n_id)
      s.save
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
