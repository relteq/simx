module Aurora
  class InitialCondition
    many_to_one :ic_set,      :class => InitialConditionSet
    many_to_one :link_family, :key => :link_id
  end
end
