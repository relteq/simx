module Aurora
  class CapacityProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :capacity_profile_set_id
    one_to_many :cps, :key => :capacity_profile_set_id, 
                :class => CapacityProfile

    def clear_members
      cps.each do |cp|
        cp.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
