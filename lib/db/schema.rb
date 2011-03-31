## eventually use migrations instead

DB.table_exists? :scenarios or DB.create_table :scenarios do
  primary_key :id

  ## ignore display
  
  ## InitialDensityProfile
  ## SRProfile
  ## CapacityProfile
  ## EventList
  ## DemandProfile
  
  ## These should be in network (ignore for now):
  ## DirectionsCache
  ## IntersectionCache

  foreign_key :network_id, :networks
end

DB.table_exists? :networks or DB.create_table :networks do
  primary_key :id
  
  ## why doesn't schema.dia have these?
  float     :x
  float     :y
  float     :z
  ## could we replace all x/y with latlng?
  
  ## MonitorList
  
  ## links
  ## ods
  ## sensors
  
  text      :name
  text      :description
  boolean   :controlled
  boolean   :top ## redundant?
  float     :tp

  foreign_key :parent_id, :networks, :key => :id
end

DB.table_exists? :vehicle_types or DB.create_table :vehicle_types do
  primary_key :id

  text      :name
  float     :weight

  foreign_key :scenario_id, :scenarios

  ## index?
  ## constraints?
end

DB.table_exists? :nodes or DB.create_table :nodes do
  primary_key :id
  
  text      :name
  text      :description
  decimal   :postmile
  text      :type ## validate
  
  float     :x
  float     :y
  float     :z

  foreign_key :network_id, :networks
end

DB.table_exists? :split_ratio_profiles or
    DB.create_table :split_ratio_profiles do
  primary_key :id
  
  ## srm?
  
  decimal   :tp
  text      :profile ## validate as ",:" delim
  
  foreign_key :node_id, :nodes
end

DB.table_exists? :links or DB.create_table :links do
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
  
  ##position ### how to represent this when nodes missing?
  ##float     :x
  ##float     :y
  ##float     :z

  foreign_key :network_id, :networks
  foreign_key :begin_id, :nodes, :key => :id
  foreign_key :end_id, :nodes, :key => :id
end
