module Aurora
  class SplitRatioProfile < Sequel::Model
    # This does not work, obviously:
    #many_to_one :node, :key => [scenario.network_id, :node_id]
    # so we must maintain this relation "manually".
    
#    many_to_one :split_ratio_profile_set
  end
end

