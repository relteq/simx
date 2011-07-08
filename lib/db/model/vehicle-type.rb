module Aurora
  class VehicleType
    many_to_one :scenario

    def copy
      v = VehicleType.new
      v.columns.each do |c|
        v.set(c => self[c]) if c != :id
      end
      return v
    end
  end
end
