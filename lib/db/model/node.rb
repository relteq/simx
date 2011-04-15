module Aurora
  class Node < Sequel::Model
#    many_to_one :network
#    many_to_one :parent, :networks

#    one_to_many :outputs, :class => "Aurora::Link", :key => :begin_id
#    one_to_many :inputs,  :class => "Aurora::Link", :key => :end_id

    # methods for working with outputs and inputs
  end
end
