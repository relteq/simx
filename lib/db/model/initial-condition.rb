module Aurora
  class InitialCondition
    many_to_one :initial_condition_set
    many_to_one :link_family, :key => :link_id
  end
end
