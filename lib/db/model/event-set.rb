module Aurora
  class EventSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :tln, :key => :network_id
    
    one_to_many :scenarios, :key => :event_set_id
    one_to_many :events, :key => :event_set_id

    def before_destroy
      events.each do |event|
        event.destroy
      end
      super
    end
  end
end
