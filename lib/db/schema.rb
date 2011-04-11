## eventually use migrations instead

def create_table? t, db = DB, &bl
  db.table_exists? t or db.create_table t, &bl
end

create_table? :scenarios do
  primary_key :id

  string :name
  text :description
  
  float :dt
  float :begin_time
  float :duration
  
  string :units ## validate: US | Metric

  ## ignore display?

  foreign_key :network_id, :networks
  
  foreign_key :ic_set_id, :initial_condition_sets
  foreign_key :dp_set_id, :demand_profile_sets
  foreign_key :cp_set_id, :capacity_profile_sets
  foreign_key :srp_set_id, :splitratio_profile_sets
  foreign_key :event_set_id, :event_sets
  foreign_key :ctrl_set_id, :controller_sets
end

create_table? :networks do
  primary_key :id
  
  text      :name
  text      :description
  float     :dt
  boolean   :ml_control
  boolean   :q_control

  float     :lat
  float     :lng
  float     :elevation, :default => 0
  
  ## MonitorList
  
  ## links
  ## ods
  ## sensors
  
  ## DirectionsCache
  ## IntersectionCache

  foreign_key :parent_id, :networks, :key => :id
end

create_table? :vehicle_types do
  primary_key :id

  text      :name
  float     :weight

  foreign_key :scenario_id, :scenarios

  ## index?
  ## constraints?
end

create_table? :nodes do
  primary_key :id
  
  text      :name
  text      :description
  decimal   :postmile
  text      :type ## validate
  
  float     :lat
  float     :lng
  float     :elevation, :default => 0

  foreign_key :network_id, :networks
end

create_table? :split_ratio_profiles do
  primary_key :id
  
  ## srm?
  
  decimal   :dt
  text      :profile ## validate as ",:" delim
  
  foreign_key :node_id, :nodes
end

create_table? :links do
  primary_key :id
  
  text      :name
  text      :description
  integer   :lanes
  float     :length
  text      :type ## validate
  ## ignore record
  
  ##fd
  ##density
  ##dynamics
  ##demand
  ##capacity
  ##qmax
  
  foreign_key :network_id, :networks
  foreign_key :begin_id, :nodes, :key => :id
  foreign_key :end_id, :nodes, :key => :id
end
