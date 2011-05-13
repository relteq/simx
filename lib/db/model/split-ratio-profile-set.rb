module Aurora
  class SplitRatioProfileSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :srp_set_id
    one_to_many :srps, :key => :srp_set_id, :class => SplitRatioProfile

    def before_destroy
      srps.each do |srp|
        srp.destroy
      end
      super
    end
  end
end
