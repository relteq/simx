module Aurora
  class RouteFamily < Sequel::Model
    one_to_many :routes
  end
  
  class Route < Sequel::Model
    many_to_one :tln, :key => :network_id
    many_to_one :route_family
    many_to_one :parent, :class => :Network, :key => [:network_id, :parent_id]

    many_to_many :links, :join_table => :route_links,
      :left_key  => [:network_id, :route_id],
      :right_key => [:network_id, :link_id]
  end
end
