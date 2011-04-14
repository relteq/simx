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
  check       :units => %w{ US Metric }

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
  decimal     :postmile
  text        :type
  check       :type => %w{ F H S P O T }
  
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
  check       :type => %w{ FW HW HOV HOT HV ETC OR FR IC ST D }
  
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

create_table? :splitratio_profile_set do
  primary_key :id
  
  text        :description
  
  # For editing. This does not restrict the networks that this set
  # may be associated with through a scenario. (There's no constraint
  # that the network of the scenario is the network of the scenario's
  # splitratio_profile_set.)
  foreign_key :network_id, :networks, :key => :network_id, :null => false
end

create_table? :splitratio_profiles do
  primary_key :id
  
  decimal     :dt
  text        :profile # xml text of form <srm>...</srm><srm>...</srm>...
  
  foreign_key :srp_set_id,    :splitratio_profile_sets, :null => false

  # Note this is only half of the composite primary key on nodes. You also
  # need to know the network ID. However, do not use the splitratio_profile_set
  # network_id, because that is only for editing purposes. The network
  # ID for node lookup must come from the scenario.
  foreign_key :node_id, :nodes, :null => false
end
