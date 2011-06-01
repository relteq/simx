module Aurora
  class SplitRatioProfile
    many_to_one :split_ratio_profile_set, :class => SplitRatioProfileSet
    many_to_one :node_family, :key => :node_id
  end
end
