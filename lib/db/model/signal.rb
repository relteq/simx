module Aurora
  class Signal
    one_to_many :phases

    many_to_one :network, :class => Network, :key => :network_id
    many_to_one :node,    :class => Node, :key => [:network_id, :node_id]

    def copy
      ###
    end

    def clear_members
      phases.each do |phase|
        phase.destroy
      end
    end

    def before_destroy
      clear_members
      super
    end
  end
end
