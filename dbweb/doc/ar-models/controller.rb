class Controller < ActiveRecord::Base
  belongs_to:controller_set
  
  def dt_to_time_format
    Time.at(Time.gm(2000,1,1) + (read_attribute("dt") || 0.0  * 3600)).utc.strftime("%H:%M:%S").to_s
  end
end
