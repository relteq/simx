module Aurora
  class CapacityProfile < Sequel::Model
    many_to_one :capacity_profile_set, :key => :cp_set_id
    many_to_one :link_family, :key => :link_id
  end
end
