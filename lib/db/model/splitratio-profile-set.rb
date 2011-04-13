module Aurora
  class SplitratioProfileSet < Sequel::Model
    many_to_one :network ## "for editing"
    one_to_many :spitratio_profiles
  end
end

