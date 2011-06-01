module Aurora
  class DemandProfile
    many_to_one :demand_profile_set
    many_to_one :link_family, :key => :link_id
  end
end
