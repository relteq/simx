module Aurora
  class SplitRatioProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :split_ratio_profile_set_id
    one_to_many :srps, :key => :split_ratio_profile_set_id, 
                :class => SplitRatioProfile

    def clear_members
      srps.each do |srp|
        srp.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
