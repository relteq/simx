module Aurora
  class RouteFamily
    one_to_many :routes, :key => :id
  end
  
  class Route
    many_to_one :tln, :key => :network_id
    many_to_one :route_family, :key => :id
    many_to_one :parent, :class => Network, :key => [:network_id, :parent_id]

    many_to_many :links, :join_table => :route_links,
      :left_key  => [:network_id, :route_id],
      :right_key => [:network_id, :link_id]
  end
end
