module Aurora
  class NodeFamily < Sequel::Model
    one_to_many :nodes
  end
  
  class Node < Sequel::Model
    many_to_one :tln, :key => :network_id
    many_to_one :node_family
    many_to_one :parent, :class => :Network, :key => [:network_id, :parent_id]

    one_to_many :inputs,  :class => :Link, :key => [:network_id, :end_id]
    one_to_many :outputs, :class => :Link, :key => [:network_id, :begin_id]
  end
end
