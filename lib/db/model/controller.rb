module Aurora
  class Controller < Sequel::Model
    many_to_one :controller_set, :key => :cset_id
    
    one_to_one :network_controller, :key => :controller_id
    one_to_one :node_controller, :key => :controller_id
    one_to_one :link_controller, :key => :controller_id
  end

  class NetworkController < Sequel::Model
    many_to_one :controller, :key => :controller_id
    many_to_one :network_family, :key => :network_id
  end

  class NodeController < Sequel::Model
    many_to_one :controller, :key => :controller_id
    many_to_one :node_family, :key => :node_id
  end

  class LinkController < Sequel::Model
    many_to_one :controller, :key => :controller_id
    many_to_one :link_family, :key => :link_id
  end
end
