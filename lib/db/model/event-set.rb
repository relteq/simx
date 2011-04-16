module Aurora
  class EventSet < Sequel::Model
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :eset_id
    one_to_many :events, :key => :eset_id
  end
end

