module Aurora
  class Event
    plugin :single_table_inheritance, :type
    many_to_one :event_set, :key => :event_set_id

		def copy
			e = Event.new
			e.columns.each do |c|
				e.set(c => self[c]) if c != :id
			end
			return e
		end
  end

  class NetworkEvent < Event
    many_to_one :network, :key => :network_id
  end

  class NodeEvent < Event
    many_to_one :node_family, :key => :node_id
  end

  class LinkEvent < Event
    many_to_one :link_family, :key => :link_id
  end
end
