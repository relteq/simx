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
    
    # The following relations are so we know which network to use when
    # editing a set. It doesn't restrict which networks can be used with
    # the set in a scenario.
#    one_to_many :initial_condition_sets
#    one_to_many :demand_profile_sets
#    one_to_many :capacity_profile_sets
#    one_to_many :splitratio_profile_sets
#    one_to_many :event_sets
#    one_to_many :controller_sets
  end
end
