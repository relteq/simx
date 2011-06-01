module Aurora
  class InitialConditionSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :ic_set_id
    one_to_many :initial_conditions, :key => :initial_condition_set_id

    def clear_members
      ics.each do |ic|
        ic.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
