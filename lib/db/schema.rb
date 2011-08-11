## what indexes do we need?

require 'db/util'

module Aurora
  def self.create_tables? db=DB
    # For testing, this is a stub.
    create_table? :projects, db do
      primary_key :id
    end

    create_table? :scenarios, db do
      primary_key :id
      foreign_key :project_id, :projects

      string      :name
      text        :description

      float       :dt
      float       :begin_time
      float       :duration

      check        {dt > 0}
      check        {begin_time >= 0}
      check        {duration >= 0}

      string      :units
      check       :units => Aurora::UNITS

      foreign_key :network_id, :networks, :null => false

      foreign_key :initial_condition_set_id,    :initial_condition_sets
      foreign_key :demand_profile_set_id,       :demand_profile_sets
      foreign_key :capacity_profile_set_id,     :capacity_profile_sets
      foreign_key :split_ratio_profile_set_id,  :split_ratio_profile_sets
      foreign_key :event_set_id,                :event_sets
      foreign_key :controller_set_id,           :controller_sets
      integer     :user_id_creator
      integer     :user_id_modifier

      timestamp   :updated_at
    end

    create_table? :vehicle_types, db do
      primary_key :id

      string      :name, :null => false
      float       :weight
      check       {weight > 0}

      foreign_key :scenario_id, :scenarios, :null => false
    end

    # The next set of tables just keep track of ids. Each id in one of these
    # tables corresponds to a whole family of nodes (or links or ...) that all
    # have the same id, but different network_id. This id is used as the second
    # part of the composite key in the node table. The main reason for these
    # tables is so that tables like split_ratio_profiles have a way to refer to
    # a node family, rather than a specific node, by foreign key.
    #
    # These tables also provides a convenient way to generate new ids that are
    # unique across all nodes. This makes it possible, when pasting from one
    # network to another, to overwrite an element of the same family while
    # preserving elements of different families.
    #
    # The name "family" is intended to emphasize that nodes of the same family
    # either are descendants of a common ancestor by way of copying and pasting
    # or duplication or have been explicitly given a commmon identity by the
    # user or application.

    create_table? :node_families, db do
      primary_key :id
    end

    create_table? :link_families, db do
      primary_key :id
    end

    create_table? :route_families, db do
      primary_key :id
    end

    create_table? :sensor_families, db do
      primary_key :id
    end

    create_table? :networks, db do
      primary_key :id
      foreign_key :project_id, :projects

      text        :name
      text        :description
      float       :dt
      check       {dt > 0}
      boolean     :ml_control
      boolean     :q_control

      float       :lat
      float       :lng
      float       :elevation, :default => 0

      text        :directions_cache     ## xml, but could be put in tables
      text        :intersection_cache   ## ditto

      integer     :user_id_creator
      integer     :user_id_modifier
      timestamp   :updated_at
    end

    create_table? :network_lists, db do
      foreign_key :network_id, :networks, :null => false
      foreign_key :child_id, :networks, :null => false
    end

    # The next section defines the subcomponents of networks (as opposed to the
    # various profile sets, event sets, and controller sets, which are in the
    # scenario). These tables use a composite key:
    #
    #   (network_id, id)
    #
    # The id (second half of the composite key) is unique only among elements of
    # the same type within the same network. This is so that events that refer
    # to a subnetwork can port to variants, for example. There are many foreign
    # keys that refer to this kind of id; these foreign keys are incomplete and
    # can only reference a row when combined with a network_id. When the
    # reference is internal to the network (e.g. parent_id, begin_id), we just
    # use the same network_id. When the reference is external (e.g. from an
    # event), we need to combine it with a network_id (specified by the
    # scenario's network, or a subnetwork of that).
    #
    # Distinctly created (not copied) entities remain distinct in the database,
    # so that they can be copied and pasted alongside each other.
    #
    # See dbweb/doc/subnetworks.txt for details.

    create_table? :nodes, db do
      # This network_id is the id of the network to which the node belongs.
      # This is ID changes when pasting the node into a different network.
      # Serialized in xml implicitly using the hierarchy.
      foreign_key :network_id, :networks, :null => false
      foreign_key :id, :node_families, :null => false
      primary_key [:network_id, :id]

      text        :name
      text        :description
      text        :type_node
      check       :type_node => Aurora::NODE_TYPES

      float       :lat
      float       :lng
      float       :elevation, :default => 0
    end

    create_table? :links, db do
      foreign_key :network_id, :networks, :null => false
      foreign_key :id, :link_families, :null => false
      primary_key [:network_id, :id]

      text        :name
      text        :description
      float       :lanes # fractional lanes is allowed
      float       :length
      text        :type_link
      text        :road_name, :default => ""
      decimal     :lane_offset, :default => 0

      check       {lanes >= 0}
      check       {length >= 0}
      check       :type_link => Aurora::LINK_TYPES

      string      :fd
      float       :qmax
      string      :dynamics, :default => "CTM"
      check       :dynamics => Aurora::DYNAMICS

      # Applies to end node.
      text        :weaving_factors

      integer     :begin_id, :null => false
      foreign_key [:network_id, :begin_id], :nodes, :key => [:network_id, :id]

      integer     :end_id, :null => false
      foreign_key [:network_id, :end_id], :nodes, :key => [:network_id, :id]

      integer     :begin_order  # ordinal of this link among all with same begin
      integer     :end_order    # ordinal of this link among all with same end
    end

    create_table? :routes, db do
      foreign_key :network_id, :networks, :null => false
      foreign_key :id, :route_families, :null => false
      primary_key [:network_id, :id]

      string      :name
    end

    create_table? :route_links, db do
      foreign_key :network_id, :networks, :null => false
      integer     :route_id, :null => false
      integer     :link_id, :null => false

      primary_key [:network_id, :route_id, :link_id]

      foreign_key [:network_id, :route_id], :routes, :key => [:network_id, :id]
      foreign_key [:network_id, :link_id], :links, :key => [:network_id, :id]

      integer     :ordinal, :null => false
      check       {ordinal >= 0}
      unique      [:network_id, :route_id, :ordinal]
    end

    create_table? :sensors, db do
      foreign_key :network_id, :networks, :null => false
      foreign_key :id, :sensor_families, :null => false
      primary_key [:network_id, :id]

      text        :description

      integer     :link_id, :null => true
      foreign_key [:network_id, :link_id], :links, :key => [:network_id, :id]

      string      :type_sensor
      check       :type_sensor => Aurora::SENSOR_TYPES

      string      :link_type
      check       :link_type => Aurora::SENSOR_LINK_TYPES

      text        :parameters
      text        :data_sources

      float       :display_lat
      float       :display_lng

      float       :lat
      float       :lng
      float       :elevation, :default => 0
    end

    create_table? :signalized_intersections, db do
      foreign_key :node_id, :node_families, :null => false
      foreign_key :input_link_id, :link_families, :null => false
      integer     :phase
    end

    # The following tables, including various sets, profiles, events, and
    # controllers, are edited externally to the networks. They can be mixed
    # and matched with networks when specifying a scenario.

    # Note on set tables:
    #
    # The network_id is for editing. This does not restrict the networks that
    # this set may be associated with through a scenario. There's no
    # constraint that the network of the scenario be identical to the network
    # of the scenario's split_ratio_profile_set.

    create_table? :split_ratio_profile_sets, db do
      primary_key :id
      string      :name
      text        :description
      foreign_key :network_id, :networks, :null => false
      integer     :user_id_creator
      integer     :user_id_modifier
      timestamp   :updated_at
    end

    create_table? :capacity_profile_sets, db do
      primary_key :id
      string      :name
      text        :description
      foreign_key :network_id, :networks, :null => false
      integer     :user_id_creator
      integer     :user_id_modifier
      timestamp   :updated_at
    end

    create_table? :demand_profile_sets, db do
      primary_key :id
      string      :name
      text        :description
      foreign_key :network_id, :networks, :null => false
      integer     :user_id_creator
      integer     :user_id_modifier
      timestamp   :updated_at
    end

    create_table? :initial_condition_sets, db do
      primary_key :id
      string      :name
      text        :description
      foreign_key :network_id, :networks, :null => false
    end

    create_table? :event_sets, db do
      primary_key :id
      string      :name
      text        :description
      foreign_key :network_id, :networks, :null => false
      integer     :user_id_creator
      integer     :user_id_modifier
      timestamp   :updated_at
    end

    create_table? :controller_sets, db do
      primary_key :id
      string      :name
      text        :description
      foreign_key :network_id, :networks, :null => false
      integer     :user_id_creator
      integer     :user_id_modifier
      timestamp   :updated_at
    end

    # Note on profile, event, and controller tables:
    #
    # The node_id (or link_id) is only half of the composite primary key on
    # nodes. It tells you the familiy of the node, but not the specific
    # node. To get the specific node, you also need to know the top level
    # network ID. However, do not use the split_ratio_profile_set
    # network_id, because that is only for editing purposes. The network ID
    # for node lookup must come from the scenario.

    create_table? :split_ratio_profiles, db do
      primary_key :id

      float       :start_time, :default => 0
      check       {start_time >= 0}

      float       :dt
      check       {dt > 0}

      text        :profile # xml text of form <srm>...</srm><srm>...</srm>...

      foreign_key :split_ratio_profile_set_id, 
                  :split_ratio_profile_sets, 
                  :null => false
      foreign_key :node_id, :node_families, :null => false
    end

    create_table? :capacity_profiles, db do
      primary_key :id

      float       :start_time, :default => 0
      check       {start_time >= 0}

      float       :dt
      check       {dt > 0}

      text        :profile # xml text

      foreign_key :capacity_profile_set_id, 
                  :capacity_profile_sets, 
                  :null => false
      foreign_key :link_id, :link_families, :null => false
    end

    create_table? :demand_profiles, db do
      primary_key :id

      float       :start_time, :default => 0
      check       {start_time >= 0}

      float       :dt
      check       {dt > 0}

      string      :knob

      text        :profile # xml text

      foreign_key :demand_profile_set_id, 
                  :demand_profile_sets, 
                  :null => false
      foreign_key :link_id, :link_families, :null => false
    end

    create_table? :initial_conditions, db do
      primary_key :id

      text        :density

      foreign_key :initial_condition_set_id, 
                  :initial_condition_sets, 
                  :null => false
      foreign_key :link_id, :link_families, :null => false
    end

    create_table? :events, db do
      primary_key :id

      string      :type, :null => false
      check       :type => Aurora::EVENT_STI_TYPES

      # Rails app requires these three foreign keys, does not
      # know about link_event, node_event, and network_event
      # tables.
      foreign_key :node_id, :node_families
      foreign_key :link_id, :link_families
      foreign_key :network_id, :networks

      string      :event_type
      check       :event_type => Aurora::EVENT_TYPES

      float       :time
      check       {time >= 0}

      boolean     :enabled

      text        :parameters

      foreign_key :event_set_id, :event_sets, :null => false
    end

    create_table? :controllers, db do
      primary_key :id

      string      :type, :null => false
      check       :type => Aurora::CONTROL_STI_TYPES

      # Rails app requires these three foreign keys, does not
      # know about link_controller, node_controller, and 
      # network_controller tables.
      foreign_key :node_id, :node_families, :key => :id
      foreign_key :link_id, :link_families, :key => :id
      foreign_key :network_id, :networks, :key => :id

      string      :controller_type
      check       :controller_type => Aurora::CONTROLLER_TYPES

      float       :dt
      check       {dt > 0}

      boolean     :use_sensors

      text        :parameters

      foreign_key :controller_set_id,
                  :controller_sets,
                  :null => false
    end

    # Not complete table, just keeping columns we need
    create_table? :simulation_batch_reports, db do
      primary_key :id
      
      integer  :simulation_batch_list_id
      boolean  :or_perf_c
      boolean  :route_perf_c
      boolean  :route_tt_c
      string   :report_type
      string   :xml_key
      string   :s3_bucket
    end
  end
end
