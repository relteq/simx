module Aurora
  class SignalFamily
    one_to_many :signal, :key => :id
  end
  
  class Signal
    many_to_one :network, :key => :network_id
    many_to_one :signal_family, :key => :id

    one_to_many :phases,  :key => [:network_id, :signal_id]
    many_to_one :node_family, :key => :node_id

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
