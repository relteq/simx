module Aurora
  class Scenario
    many_to_one :project

    many_to_one :tln, :key => :tln_id
    many_to_one :network_family, :key => :network_family_id
    many_to_one :network, :key => [:tln_id, :network_family_id]
    
    many_to_one :srp_set,   :class => SplitRatioProfileSet
    many_to_one :cp_set,    :class => CapacityProfileSet
    many_to_one :dp_set,    :class => DemandProfileSet
    many_to_one :ic_set,    :class => InitialConditionSet
    many_to_one :event_set, :class => EventSet
    many_to_one :ctrl_set,  :class => ControllerSet

    one_to_many :vehicle_types

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
