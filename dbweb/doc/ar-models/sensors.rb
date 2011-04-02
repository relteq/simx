class Sensors < ActiveRecord::Base
  has_many:sensor_locations
  has_many:links, :through => :sensor_locations
  has_many:networks, :through => :sensor_locations
  
end
