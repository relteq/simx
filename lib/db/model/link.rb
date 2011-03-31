module Aurora
  class Link < Sequel::Model
    many_to_one :network
    one_to_many :split_ratio_profiles
    
    many_to_one :begin, :class => "Aurora::Node"
    many_to_one :end,   :class => "Aurora::Node"
  end
end
