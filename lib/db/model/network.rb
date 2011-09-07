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
    one_to_many :signals, :key => :network_id

    def shallow_copy_children
      [nodes,links,sensors,routes].flatten
    end

    def shallow_copy_parent_field
      :network_id
    end

    def shallow_copy(db=DB, overrides = {})
      me_copy = super(db, overrides)

      db[:route_links].where(:network_id => self.id).each do |rl|
        db[:route_links] << {
          :network_id => me_copy.id,
          :route_id => rl[:route_id],
          :link_id => rl[:link_id],
          :ordinal => rl[:ordinal]
        }
      end

      children.each do |child|
        child_copy = child.shallow_copy
        db[:network_lists] << {
          :network_id => me_copy.id,
          :child_id => child_copy.id
        }
      end

      return me_copy
    end

    def deep_copy(db = DB, overrides = {})
      n = shallow_copy(db, overrides)

      [:split_ratio_profile_set, :capacity_profile_set,
       :demand_profile_set, :initial_condition_set,
       :event_set, :controller_set].each do |set_type|
        set = self.send(set_type)
        set.each do |member|
          m_copy = member.shallow_copy
          m_copy.network_id = n.id
          m_copy.save
        end
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
