module Aurora
  class VehicleType < Sequel::Model
    many_to_one :scenario
  end
end
