module Aurora
  class SplitRatioProfileSet < Sequel::Model
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :srp_set_id
    one_to_many :split_ratio_profiles, :key => :srp_set_id
  end
end

