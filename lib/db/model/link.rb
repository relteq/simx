module Aurora
  class LinkFamily < Sequel::Model
    one_to_many :links
  end
  
  class Link < Sequel::Model
    many_to_one :tln, :key => :network_id
    many_to_one :link_family
    many_to_one :parent, :class => :Network, :key => [:network_id, :parent_id]

    many_to_one :begin, :class => :Node, :key => [:network_id, :begin_id]
    many_to_one :end,   :class => :Node, :key => [:network_id, :end_id]

    many_to_many :routes, :join_table => :route_links,
      :left_key  => [:network_id, :link_id],
      :right_key => [:network_id, :route_id]

    one_to_many :sensors, :key => [:network_id, :link_id]
  end
end
