module Aurora
  class EventSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :event_set_id
    one_to_many :events, :key => :event_set_id

    def clear_members
      events.each do |event|
        event.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
