require 'db/model/scenario'
module Aurora
  class Network < Sequel::Model
    many_to_one :tln

#    many_to_one :parent, :class => self
#    one_to_many :children, :key => :parent_id, :class => self

#    one_to_many :nodes
#    one_to_many :links
#    one_to_many :sensors
#    one_to_many :routes
  end
end
