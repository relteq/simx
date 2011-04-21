module Aurora
  class DemandProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :dp_set_id
    one_to_many :dps, :key => :dp_set_id, :class => DemandProfile
  end
end

