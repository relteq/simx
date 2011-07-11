module Aurora
  class CapacityProfile
    many_to_one :cp_set,      :class => CapacityProfileSet
    many_to_one :link_family, :key => :link_id

    def copy
      cp = CapacityProfile.new
      cp.columns.each do |c|
        cp.set(c => self[c]) if c != :id
      end
      return cp
    end
  end
end
