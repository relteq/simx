module Aurora
  class ControllerSet < Sequel::Model
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :cset_id
    one_to_many :controllers, :key => :cset_id
  end
end

