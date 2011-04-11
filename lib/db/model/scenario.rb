module Aurora
  class Scenario < Sequel::Model
    ##many to one :project

    many_to_one :network
    
    many_to_one :ic_set, :class => "Aurora::IntersectionControllerSet"
    many_to_one :dp_set, :class => "Aurora::DemandProfileSet"
    many_to_one :cp_set, :class => "Aurora::CapacityProfileSet"
    many_to_one :srp_set, :class => "Aurora::SplitratioProfileSet"
    many_to_one :event_set, :class => "Aurora::EventSet"
    many_to_one :ctrl_set, :class => "Aurora::ControllerSet"

    one_to_many :vehicle_types
  end
end
