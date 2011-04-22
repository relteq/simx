module Aurora
  class CapacityProfile
    many_to_one :cp_set,      :class => CapacityProfileSet
    many_to_one :link_family, :key => :link_id
  end
end
