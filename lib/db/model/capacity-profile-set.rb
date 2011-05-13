module Aurora
  class CapacityProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :cp_set_id
    one_to_many :cps, :key => :cp_set_id, :class => CapacityProfile

    def before_destroy
      cps.each do |cp|
        cp.destroy
      end
      super
    end
  end
end
