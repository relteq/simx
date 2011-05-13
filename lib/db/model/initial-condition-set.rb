module Aurora
  class InitialConditionSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :ic_set_id
    one_to_many :ics, :key => :ic_set_id, :class => InitialCondition

    def before_destroy
      ics.each do |ic|
        ic.destroy
      end
      super
    end
  end
end
