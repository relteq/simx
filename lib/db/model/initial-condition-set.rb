module Aurora
  class InitialConditionSet < Sequel::Model
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :ic_set_id
    one_to_many :initial_condition_profiles, :key => :ic_set_id
  end
end

