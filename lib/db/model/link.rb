module Aurora
  class Link < Sequel::Model
    many_to_one :network
    
#    many_to_one :begin, :class => "Aurora::Node"
#    many_to_one :end,   :class => "Aurora::Node"
  end
end
