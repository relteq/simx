module Aurora
  class DemandProfile < Sequel::Model
    many_to_one :demand_profile_set, :key => :dp_set_id
    many_to_one :link_family, :key => :link_id
  end
end
