module Aurora
  class LinkFamily
    one_to_many :links, :key => :id
  end
  
  class Link
    many_to_one :network, :key => :network_id
    many_to_one :link_family, :key => :id

    many_to_one :begin_node, :class => Node, :key => [:network_id, :begin_id]
    many_to_one :end_node,   :class => Node, :key => [:network_id, :end_id]

    many_to_many :routes, :join_table => :route_links,
      :left_key  => [:network_id, :link_id],
      :right_key => [:network_id, :route_id]

    one_to_many :sensors, :key => [:network_id, :link_id]

    def copy
      Link.unrestrict_primary_key
      l = Link.new
      l.columns.each do |col|
        l.set(col => self[col]) unless (col == :network_id)
      end
      return l
    end
  end
end
