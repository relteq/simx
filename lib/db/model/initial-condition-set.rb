module Aurora
  class InitialConditionSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :ic_set_id
    one_to_many :initial_conditions, :key => :initial_condition_set_id

    def shallow_copy
      ics = InitialConditionSet.new
      ics.columns.each do |c|
        ics.set(c => self[c]) if c != :id
      end
      ics.save

      initial_conditions.each do |ic|
        icopy = ic.copy
        icopy.initial_condition_set_id = ics.id
        icopy.save
      end
      return ics
    end

    def clear_members
      initial_conditions.each do |ic|
        ic.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
