module Aurora
  class NodeFamily
    one_to_many :nodes, :key => :id
  end
  
  class Node
    many_to_one :network, :key => :network_id
    many_to_one :node_family, :key => :id

    one_to_many :inputs,  :class => Link, :key => [:network_id, :end_id]
    one_to_many :outputs, :class => Link, :key => [:network_id, :begin_id]
    
    one_to_one  :signal,  :class => Signal, :key => [:network_id, :node_id]

    def copy
      Node.unrestrict_primary_key
			n = Node.new
      n.columns.each do |col|
        n.set(col => self[col]) unless (col == :network_id)
      end
      return n
    end

    def clear_members
      signal.destroy if signal
    end

    def before_destroy
      clear_members
      super
    end
  end
end
