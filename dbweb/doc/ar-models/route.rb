class Route < ActiveRecord::Base

  has_many:network_routes
  has_many:networks, :through => :network_routes
  
  has_many:route_links
  has_many:links, :through => :route_links
  
end
