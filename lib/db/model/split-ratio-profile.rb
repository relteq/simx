module Aurora
  class SplitRatioProfile
    many_to_one :split_ratio_profile_set, :class => SplitRatioProfileSet
    many_to_one :node_family, :key => :node_id

		def copy
			srp = SplitRatioProfile.new
			srp.columns.each do |c|
				srp.set(c => self[c]) if c != :id
			end
			return srp
		end
  end
end
