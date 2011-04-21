module Aurora
  class CapacityProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :cp_set_id
    one_to_many :cps, :key => :cp_set_id, :class => CapacityProfile
  end
end

