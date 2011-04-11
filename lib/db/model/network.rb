require 'db/model/scenario'
module Aurora
  class Network < Sequel::Model
    one_to_many :scenarios ## all must have the same project

    one_to_many :networks, :key => :parent_id, :class => self

    one_to_many :nodes
    one_to_many :links
    
    ##one_to_many :sensors
  end
end
