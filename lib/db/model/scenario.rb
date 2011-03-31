module Aurora
  class Scenario < Sequel::Model
    one_to_many :vehicle_types
    many_to_one :network
  end
end
