class Network < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  
  belongs_to :project

  has_many :controller_sets
  has_many :split_ratio_profile_sets
  has_many :capacity_profile_sets
  has_many :demand_profile_sets
  has_many :event_sets
  has_many :events
  has_many :controllers
  has_many :demand_profiles
  has_many :scenarios
  
  has_many :network_families, :foreign_key => "network_id", :class_name => "NetworkFamily"
  has_many :children, :through => :network_families  
  
  has_many :network_routes
  has_many :routes, :through => :network_routes
 
  has_many :network_nodes
  has_many :nodes, :through => :network_nodes
 
  has_many :network_links
  has_many :links, :through => :network_links
  
  has_many :output_links
  has_many :nodes, :through => :output_links
  has_many :links, :through => :output_links

  has_many :input_links
  has_many :nodes, :through => :input_links
  has_many :links, :through => :input_links

  has_many :sensor_locations
  has_many :sensors, :through => :sensor_locations
  has_many :links, :through => :sensor_locations
  
  
  def remove_from_scenario
    #remove this demand profile set from anything it is attached to

    @scen = Scenario.find_by_network_id(id)
    if(@scen != nil)
        @scen.network_id = nil
        @scen.save
    end
  end
  
  def dt
    milliseconds_to_string_time(read_attribute("dt") || 1.0)
  end
  
  def dt=(dt)
    write_attribute("dt",milliseconds_since_midnight(dt)) 
    rescue ArgumentError
       @dt_invalid = true
  end
  
  def milliseconds_to_string_time(mil)
     hours = (mil / 3600).to_i
     minutes = ((mil - (hours * 3600)) / 60).to_i
     seconds = (mil - (hours * 3600) - (minutes * 60))  
     "%02d:%02d:%04.1f" % [hours, minutes, seconds]
  end
  
  def milliseconds_since_midnight(time)
    elems = time.split(":")
    seconds = elems[0].to_i * 3600 + elems[1].to_i * 60 + elems[2].to_f
  end
  
end
