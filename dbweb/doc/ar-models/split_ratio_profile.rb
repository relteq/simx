class SplitRatioProfile < ActiveRecord::Base
  belongs_to:split_ratio_profile_group
  belongs_to:node
  
end
