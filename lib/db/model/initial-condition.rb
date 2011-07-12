module Aurora
  class InitialCondition
    many_to_one :initial_condition_set
    many_to_one :link_family, :key => :link_id

    def copy
      ic = InitialCondition.new
      ic.columns.each do |c|
        ic.set(c => self[c]) if c != :id
      end
      return ic
    end
  end
end
