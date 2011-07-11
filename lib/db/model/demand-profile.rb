module Aurora
  class DemandProfile
    many_to_one :demand_profile_set
    many_to_one :link_family, :key => :link_id

    def copy
      dp = DemandProfile.new
      dp.columns.each do |c|
        dp.set(c => self[c]) if c != :id
      end
      return dp
    end
  end
end
