module Aurora
  class Tln < Sequel::Model
    one_to_many :scenarios, :key => :network_id
    one_to_many :networks, :key => :network_id

    # The following relations are so we know which network to use when
    # editing a set. It doesn't restrict which networks can be used with
    # the set in a scenario.
    one_to_many :srp_set,   :class => "Aurora::SplitRatioProfileSet",
      :key => :network_id
    one_to_many :cp_set,    :class => "Aurora::CapacityProfileSet",
      :key => :network_id
    one_to_many :dp_set,    :class => "Aurora::DemandProfileSet",
      :key => :network_id
    one_to_many :ic_set,    :class => "Aurora::IntersectionControllerSet",
      :key => :network_id
    one_to_many :event_set, :class => "Aurora::EventSet",
      :key => :network_id
    one_to_many :ctrl_set,  :class => "Aurora::ControllerSet",
      :key => :network_id
  end
end
