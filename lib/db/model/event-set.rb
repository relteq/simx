module Aurora
  class EventSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :event_set_id
    one_to_many :events, :key => :event_set_id

		def shallow_copy
			es = EventSet.new
			es.columns.each do |c|
				es.set(c => self[c]) if c != :id
			end
			es.save

			events.each do |e|
				ecopy = e.copy
				ecopy.event_set_id = es.id
				ecopy.save
			end

			return es
		end

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
