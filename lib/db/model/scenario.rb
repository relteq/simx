module Aurora
  class Scenario
    many_to_one :project

    many_to_one :tln
    
    many_to_one :srp_set,   :class => SplitRatioProfileSet
    many_to_one :cp_set,    :class => CapacityProfileSet
    many_to_one :dp_set,    :class => DemandProfileSet
    many_to_one :ic_set,    :class => IntersectionControllerSet
    many_to_one :event_set, :class => EventSet
    many_to_one :ctrl_set,  :class => ControllerSet

    one_to_many :vehicle_types
  end
end
