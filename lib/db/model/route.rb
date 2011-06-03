module Aurora
  class RouteFamily
    one_to_many :routes, :key => :id
  end
  
  class Route
    many_to_one :network, :key => :network_id
    many_to_one :route_family, :key => :id

    many_to_many :links, :join_table => :route_links,
      :left_key  => [:network_id, :route_id],
      :right_key => [:network_id, :link_id]

    def before_destroy
      DB[:route_links].filter(:network_id => network_id, :route_id => id).delete
      super
    end
  end
end
