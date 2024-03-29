module Aurora
  class ControllerSet
    # for editing; does not restrict combination with other scenario.network
    many_to_one :network, :key => :network_id
    
    one_to_many :scenarios, :key => :controller_set_id
    one_to_many :controllers, :key => :controller_set_id

    def shallow_copy_children
      controllers
    end

    def shallow_copy_parent_field
      :controller_set_id
    end

    def clear_members
      controllers.each do |controller|
        controller.destroy
      end
    end
    
    def before_destroy
      clear_members
      super
    end
  end
end
