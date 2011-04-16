module Aurora
  class SplitRatioProfile < Sequel::Model
    many_to_one :split_ratio_profile_set, :key => :srp_set_id
    many_to_one :node_family, :key => :node_id
  end
end
