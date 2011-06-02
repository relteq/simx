module Aurora
  class Event
    plugin :single_table_inheritance, :type
    many_to_one :event_set, :key => :event_set_id
  end

  class NetworkEvent < Event
    many_to_one :network_family, :key => :network_family_id
  end

  class NodeEvent < Event
    many_to_one :node_family, :key => :node_family_id
  end

  class LinkEvent < Event
    many_to_one :link_family, :key => :link_family_id
  end
end
