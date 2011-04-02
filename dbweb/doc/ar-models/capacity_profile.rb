class CapacityProfile < ActiveRecord::Base  
  belongs_to:capacity_profile_set
  belongs_to:link
end
