module Aurora
  class DemandProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :demand_profile_set_id
    one_to_many :dps, :key => :demand_profile_set_id, :class => DemandProfile

    def shallow_copy
      d = DemandProfileSet.new
      d.columns.each do |c|
        d.set(c => self[c]) if c != :id
      end
      d.save

      dps.each do |dp|
        dcopy = dp.copy
        dcopy.demand_profile_set_id = d.id
        dcopy.save
      end

      return d
    end

    def clear_members
      dps.each do |dp|
        dp.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
