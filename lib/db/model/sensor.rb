module Aurora
  class SensorFamily
    one_to_many :sensors, :key => :id
  end
  
  class Sensor
    many_to_one :tln, :key => :network_id
    many_to_one :sensor_family, :key => :id
    many_to_one :parent, :class => Network, :key => [:network_id, :parent_id]

    many_to_one :link, :key => [:network_id, :link_id]
  end
end

