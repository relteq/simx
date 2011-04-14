require 'db/model/scenario'
module Aurora
  class Network < Sequel::Model
    one_to_many :scenarios ## all must have the same project

    many_to_one :parent, :class => self
    one_to_many :children, :key => :parent_id, :class => self

#    one_to_many :nodes
#    one_to_many :links
    
    ###one_to_many :sensors
    ###etc
    
    one_to_many :splitratio_profile_sets ## "for editing"
  end
end
