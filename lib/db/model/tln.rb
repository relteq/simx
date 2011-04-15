module Aurora
  class Tln < Sequel::Model
    one_to_many :scenarios, :key => :network_id
    one_to_many :networks, :key => :network_id
  end
end
