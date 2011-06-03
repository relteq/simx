module Aurora
  class Controller
    plugin :single_table_inheritance, :type
    many_to_one :controller_set, :key => :controller_set_id
  end

  class NetworkController < Controller
    many_to_one :network, :key => :network_id
  end

  class NodeController < Controller
    many_to_one :node_family, :key => :node_family_id
  end

  class LinkController < Controller
    many_to_one :link_family, :key => :link_family_id
  end
end
