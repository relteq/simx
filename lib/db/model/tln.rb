module Aurora
  class Tln
    many_to_one :project

    one_to_many :scenarios, :key => :network_id

    one_to_many :networks,  :key => :network_id
    one_to_many :links,     :key => :network_id
    one_to_many :nodes,     :key => :network_id
    one_to_many :routes,    :key => :network_id
    one_to_many :sensors,   :key => :network_id

    # The following relations are so we know which network to use when
    # editing a set. It doesn't restrict which networks can be used with
    # the set in a scenario.
    k = :network_id
    one_to_many :srp_set,   :class => SplitRatioProfileSet, :key => k
    one_to_many :cp_set,    :class => CapacityProfileSet,   :key => k
    one_to_many :dp_set,    :class => DemandProfileSet,     :key => k
    one_to_many :ic_set,    :class => InitialConditionSet,  :key => k
    one_to_many :event_set, :class => EventSet,             :key => k
    one_to_many :ctrl_set,  :class => ControllerSet,        :key => k

    def clear_members
      [sensors, routes, links, nodes, networks].each do |models|
        models.each do |model|
          model.destroy
        end
      end
    end

    def before_destroy
      clear_members
      super
    end
  end
end
