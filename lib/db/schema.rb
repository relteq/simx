## use sequel_pg in production

## eventually use migrations instead

## what indexes do we need?

require 'sequel'
require 'db/util'

create_next_uniq_id_table

# For testing, this is a stub.
create_table? :projects do
  primary_key :id
end

create_table? :scenarios do
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

  # This is really a reference to all the nodes, links, subnetworks, etc.
  # that belong to one network.
  foreign_key :network_id,    :networks, :key => :network_id, :null => false
  
  foreign_key :ic_set_id,     :initial_condition_sets
  foreign_key :dp_set_id,     :demand_profile_sets
  foreign_key :cp_set_id,     :capacity_profile_sets
  foreign_key :srp_set_id,    :splitratio_profile_sets
  foreign_key :event_set_id,  :event_sets
  foreign_key :ctrl_set_id,   :controller_sets
end

create_table? :networks do
  # networks, like nodes and links, have composite primary key:
  #   [network_id, id]
  # so that events that refer to a subnetwork can port to variants.
  # The network_id is a global id that will be shared by all rows for 
  # networks, nodes, links, etc. coming from the xml being imported.
  # This ID is serialized in the xml as "network_id", but only in the top
  # network.
  # See dbweb/doc/subnetworks.txt for details.
  integer     :network_id, :null => false

  # This should usually be 1 for the top network. But, really, parent_id==nil
  # is the way to tell whether a network is top.
  # This ID is serialized in the xml as "id".
  integer     :id, :null => false

  primary_key [:network_id, :id]
  
  # note: non-unique foreign_key
  foreign_key :parent_id, :networks, :null => true
  
  text        :name
  text        :description
  float       :dt
  check       {dt > 0}
  boolean     :ml_control
  boolean     :q_control

  float       :lat
  float       :lng
  float       :elevation, :default => 0
end

create_table? :vehicle_types do
  primary_key :id

  string      :name, :null => false
  float       :weight
  check       {weight > 0}

  foreign_key :scenario_id, :scenarios, :null => false
end

create_table? :nodes do
  # This network_id is of the top network to which the node belongs, not
  # the immediate parent network. This is a global ID which changes when
  # pasting the node into a different network. Not serialized in xml.
  foreign_key :network_id, :networks, :key => :network_id, :null => false
  integer     :id, :null => false
  primary_key [:network_id, :id]

  # This id is the parent network to which the node belongs. This is a local
  # ID which is preserved when pasting the subnetwork/node. This ID is
  # serialized in xml implicitly using the hierarchy.
  foreign_key :parent_id, :networks, :null => false
  
  text        :name
  text        :description
  text        :type
  check       :type => Aurora::NODE_TYPES
  
  float       :lat
  float       :lng
  float       :elevation, :default => 0
end

create_table? :links do
  # See above.
  foreign_key :network_id, :networks, :key => :network_id, :null => false
  integer     :id, :null => false
  primary_key [:network_id, :id]
  
  # See above.
  foreign_key :parent_id, :networks, :null => false
  
  text        :name
  text        :description
  integer     :lanes
  float       :length
  text        :type

  check       {lanes >= 0}
  check       {length >= 0}
  check       :type => Aurora::LINK_TYPES
  
  string      :fd
  double      :qmax
  string      :dynamics, :default => "CTM"
  check       :dynamics => %w{ CTM }
  
  # Applies to end node.
  text        :weaving_factors
  
  # note: non-unique foreign_key
  foreign_key :begin_id, :nodes, :null => false
  integer     :begin_order # ordinal of this link among all with same begin
  
  # note: non-unique foreign_key
  foreign_key :end_id, :nodes, :null => false
  integer     :end_order # ordinal of this link among all with same end
end

create_table? :routes do
  foreign_key :network_id, :networks, :key => :network_id, :null => false
  integer     :id, :null => false
  primary_key [:network_id, :id]
  
  foreign_key :parent_id, :networks, :null => false
  
  text        :description
end

create_table? :route_links do
  foreign_key :network_id, :networks, :key => :network_id, :null => false
  integer     :id, :null => false
  primary_key [:network_id, :id]

  foreign_key :route_id, :routes, :null => false
  foreign_key :link_id, :links, :null => false
  
  integer     :order
end

create_table? :sensors do
  foreign_key :network_id, :networks, :key => :network_id, :null => false
  integer     :id, :null => false
  primary_key [:network_id, :id]

  foreign_key :parent_id, :networks, :null => false

  foreign_key :link_id, :links, :null => true

  float       :offset
  check       {offset >= 0}

  string      :type
  check       :type => Aurora::SENSOR_TYPES
  
  string      :link_type
  check       :link_type => Aurora::LINK_TYPES
  
  text        :parameters

  float       :lat
  float       :lng
  float       :elevation, :default => 0
end

# The following tables are edited externally to the networks, and can be mixed
# and matched with networks when specifying a scenario.

# Note on set tables:
#
# The network_id is for editing. This does not restrict the networks that this
# set may be associated with through a scenario. (There's no constraint
# that the network of the scenario is the network of the scenario's
# splitratio_profile_set.)

create_table? :splitratio_profile_sets do
  primary_key :id
  text        :description
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

create_table? :capacity_profile_sets do
  primary_key :id
  text        :description
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

create_table? :demand_profile_sets do
  primary_key :id
  text        :description
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

create_table? :initial_condition_sets do
  primary_key :id
  text        :description
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

create_table? :event_sets do
  primary_key :id
  text        :description
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

create_table? :controller_sets do
  primary_key :id
  text        :description
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

# Note on profile, event, and similar tables:
#
# Note node_id (or link_id) is only half of the composite primary key on nodes.
# You also need to know the network ID. However, do not use the
# splitratio_profile_set network_id, because that is only for editing purposes.
# The network ID for node lookup must come from the scenario.

create_table? :splitratio_profiles do
  primary_key :id
  
  float       :dt
  check       {dt > 0}

  text        :profile # xml text of form <srm>...</srm><srm>...</srm>...
  
  foreign_key :srp_set_id, :splitratio_profile_sets, :null => false
  foreign_key :node_id, :nodes, :null => false
end

create_table? :capacity_profiles do
  primary_key :id
  
  float       :dt
  check       {dt > 0}

  text        :profile # xml text
  
  foreign_key :cp_set_id, :capacity_profile_sets, :null => false
  foreign_key :link_id, :links, :null => false
end

create_table? :demand_profiles do
  primary_key :id
  
  float       :dt
  check       {dt > 0}

  text        :profile # xml text
  
  foreign_key :dp_set_id, :demand_profile_sets, :null => false
  foreign_key :link_id, :links, :null => false
end

create_table? :initial_conditions do
  primary_key :id
  
  text        :density
  
  foreign_key :ic_set_id, :initial_condition_sets, :null => false
  foreign_key :link_id, :links, :null => false
end

create_table? :network_events do
  primary_key :id
  
  string      :type
  float       :time
  check       {time >= 0}
  text        :parameters
  
  foreign_key :eset_id, :event_sets, :null => false
  foreign_key :network_id, :networks, :null => false
end

create_table? :node_events do
  primary_key :id
  
  string      :type
  float       :time
  check       {time >= 0}
  text        :parameters
  
  foreign_key :eset_id, :event_sets, :null => false
  foreign_key :node_id, :nodes, :null => false
end

create_table? :link_events do
  primary_key :id
  
  string      :type
  float       :time
  check       {time >= 0}
  text        :parameters
  
  foreign_key :eset_id, :event_sets, :null => false
  foreign_key :link_id, :links, :null => false
end

create_table? :network_controllers do
  primary_key :id
  
  string      :type
  float       :dt
  check       {dt > 0}
  text        :parameters
  
  foreign_key :cset_id, :controller_sets, :null => false
  foreign_key :network_id, :networks, :null => false
end

create_table? :node_controllers do
  primary_key :id
  
  string      :type
  float       :dt
  check       {dt > 0}
  text        :parameters
  
  foreign_key :cset_id, :controller_sets, :null => false
  foreign_key :node_id, :nodes, :null => false
end

create_table? :link_controllers do
  primary_key :id
  
  string      :type
  float       :dt
  check       {dt > 0}
  text        :parameters
  
  foreign_key :cset_id, :controller_sets, :null => false
  foreign_key :link_id, :links, :null => false
end

