module Aurora
  class Event
    many_to_one :event_set, :key => :event_set_id
    
    one_to_one :network_event, :key => :event_id
    one_to_one :node_event, :key => :event_id
    one_to_one :link_event, :key => :event_id
  end

  class NetworkEvent
    many_to_one :event, :key => :event_id
    many_to_one :network_family, :key => :network_family_id
  end

  class NodeEvent
    many_to_one :event, :key => :event_id
    many_to_one :node_family, :key => :node_family_id
  end

  class LinkEvent
    many_to_one :event, :key => :event_id
    many_to_one :link_family, :key => :link_family_id
  end
end
