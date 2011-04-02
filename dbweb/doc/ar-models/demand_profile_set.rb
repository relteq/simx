class DemandProfileSet < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id

  validates_presence_of :network
  
  belongs_to:network
  belongs_to:project
  
  has_many:demand_profiles
  has_many:scenarios

  def remove_from_scenario
    #remove this demand profile set from anything it is attached to
    @scen = Scenario.find_by_demand_profile_set_id(id)
    if(@scen != nil)
        @scen.demand_profile_set_id = nil
        @scen.save
    end
  end
  
end
