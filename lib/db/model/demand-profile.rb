module Aurora
  class DemandProfile
    many_to_one :dp_set,      :class => DemandProfileSet
    many_to_one :link_family, :key => :link_id
  end
end
