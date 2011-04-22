module Aurora
  class ControllerSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :ctrl_set_id
    one_to_many :controllers, :key => :ctrl_set_id
  end
end

