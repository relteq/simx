require 'db/model/scenario'
module Aurora
  class NetworkFamily < Sequel::Model
    one_to_many :networks
  end
  
  class Network < Sequel::Model
    many_to_one :tln, :key => :network_id
    many_to_one :network_family

    many_to_one :parent,      :class => self, :key => [:network_id, :parent_id]
    one_to_many :subnetworks, :class => self, :key => [:network_id, :parent_id]
    
    one_to_many :nodes,   :key => [:network_id, :parent_id]
    one_to_many :links,   :key => [:network_id, :parent_id]
    one_to_many :sensors, :key => [:network_id, :parent_id]
    one_to_many :routes,  :key => [:network_id, :parent_id]
  end
end
