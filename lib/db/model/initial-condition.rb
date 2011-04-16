module Aurora
  class InitialCondition
    many_to_one :initial_condition_set, :key => :ic_set_id
    many_to_one :link_family, :key => :link_id
  end
end
