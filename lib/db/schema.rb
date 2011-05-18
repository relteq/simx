## what indexes do we need?

require 'sequel' ## use sequel_pg in production
require 'db/util'

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

  foreign_key :tln_id,        :tlns, :null => false
  foreign_key :network_family_id, :network_families, :null => false
  foreign_key [:tln_id, :network_family_id], :networks,
                :key => [:network_id, :id]

  foreign_key :ic_set_id,     :initial_condition_sets
  foreign_key :dp_set_id,     :demand_profile_sets
  foreign_key :cp_set_id,     :capacity_profile_sets
  foreign_key :srp_set_id,    :split_ratio_profile_sets
  foreign_key :event_set_id,  :event_sets
  foreign_key :ctrl_set_id,   :controller_sets
end

create_table? :vehicle_types do
  primary_key :id

  string      :name, :null => false
  float       :weight
  check       {weight > 0}

  foreign_key :scenario_id, :scenarios, :null => false
end

# Top-level networks. Rows in this table are one-to-one with rows in the
# networks table that have parent==null. The main reason for having this
# table separate is to provide half of the composite primary keys that
# our foreign keys that reference.
create_table? :tlns do
  primary_key :id
  foreign_key :project_id, :projects
end

# The next set of tables just keep track of ids. Each id in one of these tables
# corresponds to a whole family of nodes (or links or ...) that all have the
# same id, but different network_id. This id is used as the second part of the
# composite key in the node table. The main reason for these tables is so that
# tables like split_ratio_profiles have a way to refer to a node family, rather
# than a specific node, by foreign key. (Actually, this is not true for routes
# and sensors.)
#
# These tables also provides a convenient way to generate new ids that are
# unique across all nodes. This makes it possible, when pasting from one network
# to another, to overwrite an element of the same family while preserving
# elements of different families.
#
# The name "family" is intended to emphasize that nodes of the same family
# either are descendants of a common ancestor by way of copying and pasting or
# duplication or have been explicitly given a commmon identity by the user or
# application.

# Note that network_family.id is orthogonal to tln.id.
create_table? :network_families do
  primary_key :id
end

create_table? :node_families do
  primary_key :id
end

create_table? :link_families do
  primary_key :id
end

create_table? :route_families do
  primary_key :id
end

create_table? :sensor_families do
  primary_key :id
end

# The next section defines the subcomponents of networks (as opposed to the
# various profile sets, event sets, and controller sets, which are in the
# scenario). These tables use a composite key:
#
#   (network_id, id)
#
# The network_id refers to a unique top level network and its contents. It is
# shared by all rows created for subnetworks, nodes, links, etc. coming from
# the xml being imported as part of one network.
#
# The id (second half of the composite key) is unique only among elements of the
# same type within the same top level network. This is so that events that refer
# to a subnetwork can port to variants, for example. There are many foreign keys
# that refer to this kind of id; these foreign keys are incomplete and can only
# reference a row when combined with a network_id. When the reference is
# internal to the network (e.g. parent_id, begin_id), we just use the same
# network_id. When the reference is external (e.g. from an event), we
# combine with the network_id specified by the scenario.
#
# Distinctly created (not copied) entities remain distinct in the database, so
# that they can be copied and pasted alongside each other.
#
# See dbweb/doc/subnetworks.txt for details.

create_table? :networks do
  # Serialized in xml as "network_id", but only in the top level network.
  foreign_key :network_id, :tlns, :null => false

  # This is often 1 for the top network. But, really, parent_id==nil
  # is the way to tell whether a network is top.
  # Serialized in xml as "id".
  foreign_key :id, :network_families, :null => false

  primary_key [:network_id, :id]
  
  integer     :parent_id, :null => true
  foreign_key [:network_id, :parent_id], :networks, :key => [:network_id, :id]
  
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
end

create_table? :nodes do
  # This network_id is of the top network to which the node belongs, not
  # the immediate parent network. This is a global ID which changes when
  # pasting the node into a different network. Not serialized in xml.
  foreign_key :network_id, :tlns, :null => false
  foreign_key :id, :node_families, :null => false
  primary_key [:network_id, :id]

  # Parent network to which the node belongs. Preserved when pasting the
  # node. Serialized in xml implicitly using the hierarchy.
  integer     :parent_id, :null => false
  foreign_key [:network_id, :parent_id], :networks, :key => [:network_id, :id]
  
  text        :name
  text        :description
  text        :type
  check       :type => Aurora::NODE_TYPES
  
  float       :lat
  float       :lng
  float       :elevation, :default => 0
end

create_table? :links do
  foreign_key :network_id, :tlns, :null => false
  foreign_key :id, :link_families, :null => false
  primary_key [:network_id, :id]

  integer     :parent_id, :null => false
  foreign_key [:network_id, :parent_id], :networks, :key => [:network_id, :id]
  
  text        :name
  text        :description
  float       :lanes # fractional lanes is allowed
  float       :length
  text        :type

  check       {lanes >= 0}
  check       {length >= 0}
  check       :type => Aurora::LINK_TYPES
  
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

create_table? :routes do
  foreign_key :network_id, :tlns, :null => false
  foreign_key :id, :route_families, :null => false
  primary_key [:network_id, :id]
  
  integer     :parent_id, :null => false
  foreign_key [:network_id, :parent_id], :networks, :key => [:network_id, :id]
  
  string      :name
end

create_table? :route_links do
  foreign_key :network_id, :tlns, :null => false
  integer     :route_id, :null => false
  integer     :link_id, :null => false

  primary_key [:network_id, :route_id, :link_id]

  foreign_key [:network_id, :route_id], :routes, :key => [:network_id, :id]
  foreign_key [:network_id, :link_id], :links, :key => [:network_id, :id]
  
  integer     :order, :null => false
  check       {order >= 0}
  unique      [:network_id, :route_id, :order]
end

create_table? :sensors do
  foreign_key :network_id, :tlns, :null => false
  foreign_key :id, :sensor_families, :null => false
  primary_key [:network_id, :id]

  integer     :parent_id, :null => false
  foreign_key [:network_id, :parent_id], :networks, :key => [:network_id, :id]

  text        :description

  integer     :link_id, :null => true
  foreign_key [:network_id, :link_id], :links, :key => [:network_id, :id]

  string      :type
  check       :type => Aurora::SENSOR_TYPES
  
  string      :link_type
  check       :link_type => Aurora::SENSOR_LINK_TYPES
  
  text        :parameters
  
  float       :display_lat
  float       :display_lng

  float       :lat
  float       :lng
  float       :elevation, :default => 0
end

# The following tables, including various sets, profiles, events, and
# controllers, are edited externally to the networks. They can be mixed and
# matched with networks when specifying a scenario.

# Note on set tables:
#
# The network_id is for editing. This does not restrict the networks that this
# set may be associated with through a scenario. There's no constraint that the
# network of the scenario be identical to the network of the scenario's
# split_ratio_profile_set.

create_table? :split_ratio_profile_sets do
  primary_key :id
  string      :name
  text        :description
  foreign_key :network_id, :tlns, :null => false
end

create_table? :capacity_profile_sets do
  primary_key :id
  string      :name
  text        :description
  foreign_key :network_id, :tlns, :null => false
end

create_table? :demand_profile_sets do
  primary_key :id
  string      :name
  text        :description
  foreign_key :network_id, :tlns, :null => false
end

create_table? :initial_condition_sets do
  primary_key :id
  string      :name
  text        :description
  foreign_key :network_id, :tlns, :null => false
end

create_table? :event_sets do
  primary_key :id
  string      :name
  text        :description
  foreign_key :network_id, :tlns, :null => false
end

create_table? :controller_sets do
  primary_key :id
  string      :name
  text        :description
  foreign_key :network_id, :tlns, :null => false
end

# Note on profile, event, and controller tables:
#
# The node_id (or link_id) is only half of the composite primary key on nodes.
# It tells you the familiy of the node, but not the specific node. To get the
# specific node, you also need to know the top level network ID. However, do not
# use the split_ratio_profile_set network_id, because that is only for editing
# purposes. The network ID for node lookup must come from the scenario.

create_table? :split_ratio_profiles do
  primary_key :id
  
  float       :start_time, :default => 0
  check       {start_time >= 0}
  
  float       :dt
  check       {dt > 0}

  text        :profile # xml text of form <srm>...</srm><srm>...</srm>...
  
  foreign_key :srp_set_id, :split_ratio_profile_sets, :null => false
  foreign_key :node_id, :node_families, :null => false
end

create_table? :capacity_profiles do
  primary_key :id
  
  float       :start_time, :default => 0
  check       {start_time >= 0}
  
  float       :dt
  check       {dt > 0}

  text        :profile # xml text
  
  foreign_key :cp_set_id, :capacity_profile_sets, :null => false
  foreign_key :link_id, :link_families, :null => false
end

create_table? :demand_profiles do
  primary_key :id
  
  float       :start_time, :default => 0
  check       {start_time >= 0}
  
  float       :dt
  check       {dt > 0}
  
  float       :knob, :default => 1.0
  check       {knob > 0}

  text        :profile # xml text
  
  foreign_key :dp_set_id, :demand_profile_sets, :null => false
  foreign_key :link_id, :link_families, :null => false
end

create_table? :initial_conditions do
  primary_key :id
  
  text        :density
  
  foreign_key :ic_set_id, :initial_condition_sets, :null => false
  foreign_key :link_id, :link_families, :null => false
end

create_table? :events do
  primary_key :id
  
  string      :type
  check       :type => Aurora::EVENT_TYPES
  
  float       :time
  check       {time >= 0}
  
  boolean     :enabled
  
  text        :parameters
  
  foreign_key :event_set_id, :event_sets, :null => false
end

create_table? :network_events do
  foreign_key :event_id, :events, :primary_key => true
  foreign_key :network_family_id, :network_families, :null => false
end

create_table? :node_events do
  foreign_key :event_id, :events, :primary_key => true
  foreign_key :node_family_id, :node_families, :null => false
end

create_table? :link_events do
  foreign_key :event_id, :events, :primary_key => true
  foreign_key :link_family_id, :link_families, :null => false
end

create_table? :controllers do
  primary_key :id
  
  string      :type
  check       :type => Aurora::CONTROLLER_TYPES
  
  float       :dt
  check       {dt > 0}
  
  boolean     :use_sensors
  
  text        :parameters
  
  foreign_key :ctrl_set_id, :controller_sets, :null => false
end

create_table? :network_controllers do
  foreign_key :controller_id, :controllers, :primary_key => true
  foreign_key :network_family_id, :network_families, :null => false
end

create_table? :node_controllers do
  foreign_key :controller_id, :controllers, :primary_key => true
  foreign_key :node_family_id, :node_families, :null => false
end

create_table? :link_controllers do
  foreign_key :controller_id, :controllers, :primary_key => true
  foreign_key :link_family_id, :link_families, :null => false
end
