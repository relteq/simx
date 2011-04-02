class SplitRatioProfileSet < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :project_id
  
  validates_presence_of :network
  
  belongs_to:network
  belongs_to:project
  
  has_many:split_ratio_profiles
  has_many:scenarios
  
  def remove_from_scenario
    #remove this split ratio from anything it is attached to
    @scen = Scenario.find_by_split_ratio_profile_set_id(id)
    if(@scen != nil)
      @scen.split_ratio_profile_set_id = nil
      @scen.save
    end
  end
  
end
