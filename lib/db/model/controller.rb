module Aurora
  class Controller
    many_to_one :controller_set, :key => :ctrl_set_id
    
    one_to_one :network_controller, :key => :controller_id
    one_to_one :node_controller,    :key => :controller_id
    one_to_one :link_controller,    :key => :controller_id

    def before_destroy
      (network_controller || node_controller || link_controller).destroy
      super
    end
  end

  class NetworkController
    many_to_one :controller, :key => :controller_id
    many_to_one :network_family, :key => :network_family_id
  end

  class NodeController
    many_to_one :controller, :key => :controller_id
    many_to_one :node_family, :key => :node_family_id
  end

  class LinkController
    many_to_one :controller, :key => :controller_id
    many_to_one :link_family, :key => :link_family_id
  end
end
