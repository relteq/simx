module Aurora
  class Phase
    many_to_one :signal

    many_to_many :links, :join_table => :phase_links,
      :left_key  => :phase_id,
      :right_key => [:network_id, :link_id]

		def copy
      ###
    end
    
    def clear_members
      DB[:phase_links].filter(:network_id => network_id, :phase_id => id).delete
    end

    def before_destroy
      clear_members
      super
    end
  end
end
