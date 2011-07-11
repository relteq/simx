module Aurora
  class SensorFamily
    one_to_many :sensors, :key => :id
  end
  
  class Sensor
    many_to_one :network, :key => :network_id
    many_to_one :sensor_family, :key => :id

    many_to_one :link, :key => [:network_id, :link_id]

    def copy
      Sensor.unrestrict_primary_key
      s = Sensor.new
      s.columns.each do |col|
        s.set(col => self[col]) unless (col == :network_id)
      end
      return s
    end
  end
end

