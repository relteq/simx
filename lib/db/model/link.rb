module Aurora
  class Link < Sequel::Model
#    many_to_one :network
#    many_to_one :parent, :networks
    
#    many_to_one :begin, :class => "Aurora::Node"
#    many_to_one :end,   :class => "Aurora::Node"

#    many_to_many :routes, :join_table => :route_links
#    one_to_many :sensors

    # methods for working with begin and end
  end
end
