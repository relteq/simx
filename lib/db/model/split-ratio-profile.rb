module Aurora
  class SplitRatioProfile
    many_to_one :srp_set,     :class => SplitRatioProfileSet
    many_to_one :node_family, :key => :node_id
  end
end
