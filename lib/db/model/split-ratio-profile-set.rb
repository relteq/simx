module Aurora
  class SplitRatioProfileSet < Sequel::Model
    many_to_one :network ## "for editing"
    one_to_many :split_ratio_profiles
  end
end

