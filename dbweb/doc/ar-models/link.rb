class Link < ActiveRecord::Base
  
  has_many:capacity_profiles
  has_many:demand_profiles
  has_many:events
  has_many:controllers
  
  has_many:route_links
  has_many:routes, :through => :route_links
  
  has_many:network_links
  has_many:networks, :through => :network_links
  
  has_many:output_links
  has_many:nodes, :through => :output_links
  has_many:networks, :through => :output_links

  has_many:input_links
  has_many:nodes, :through => :input_links
  has_many:networks, :through => :input_links
  
  has_many:sensor_locations
  has_many:sensors, :through => :sensor_locations
  has_many:networks, :through => :sensor_locations
  
end
