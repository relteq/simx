module Aurora
  class Network
    many_to_one :project

    one_to_many :scenario, :key => :network_id
    
    many_to_many :parents, :join_table => :network_lists, :class => self,
      :left_key  => :network_id, :right_key => :child_id
    many_to_many :children, :join_table => :network_lists, :class => self,
      :left_key  => :child_id, :right_key => :network_id

    one_to_many :nodes,   :key => :network_id
    one_to_many :links,   :key => :network_id
    one_to_many :sensors, :key => :network_id
    one_to_many :routes,  :key => :network_id

    def shallow_copy(db=DB)
      n = Network.new
      n.columns.each do |col|
        n.set(col => self[col]) if col != :id
      end
      n.save

      nodes.each do |node|
        ncopy = node.copy
        ncopy.network_id = n.id
        ncopy.save
      end

      links.each do |link|
        lcopy = link.copy
        lcopy.network_id = n.id
        lcopy.save
      end

      sensors.each do |sensor|
        scopy = sensor.copy
        scopy.network_id = n.id
        scopy.save
      end

      routes.each do |route|
        rcopy = route.copy
        rcopy.network_id = n.id
        rcopy.save
      end

      db[:route_links].where(:network_id => self.id).each do |rl|
        db[:route_links] << {
          :network_id => n.id,
          :route_id => rl[:route_id],
          :link_id => rl[:link_id],
          :ordinal => rl[:ordinal]
        }
      end
      
      return n
    end

    # The following relations are so we know which network to use when
    # editing a set. It doesn't restrict which networks can be used with
    # the set in a scenario.
    [ [:split_ratio_profile_set, SplitRatioProfileSet],
      [:capacity_profile_set,    CapacityProfileSet],
      [:demand_profile_set,      DemandProfileSet],
      [:initial_condition_set,   InitialConditionSet],
      [:event_set,               EventSet],
      [:controller_set,          ControllerSet] ].
    each do |set_name, set_class|
      one_to_many set_name, :Class => set_class, :key => :network_id
    end

    def clear_members
      [sensors, routes, links, nodes].each do |models|
        models.each do |model|
          model.destroy
        end
      end
    end

    def before_destroy
      clear_members
      ### do something with network_lists?
      super
    end
  end
end
