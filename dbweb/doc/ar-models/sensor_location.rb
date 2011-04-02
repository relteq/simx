class SensorLocation < ActiveRecord::Base
  belongs_to :network
  belongs_to :link
  belongs_to :sensor
  
end
