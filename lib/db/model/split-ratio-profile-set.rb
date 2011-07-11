module Aurora
  class SplitRatioProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :split_ratio_profile_set_id
    one_to_many :srps, :key => :split_ratio_profile_set_id, 
                :class => SplitRatioProfile

		def shallow_copy
			srp = SplitRatioProfileSet.new
			srp.columns.each do |c|
				srp.set(c => self[c]) if c != :id
			end
			srp.save

			srps.each do |s|
				copy = s.copy
				copy.split_ratio_profile_set_id = srp.id
				copy.save
			end
		end

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
