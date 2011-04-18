module Aurora
  class NetworkFamily
    one_to_many :networks, :key => :id
    one_to_many :scenario, :key => :network_family_id
  end
  
  class Network
    many_to_one :tln, :key => :network_id
    many_to_one :network_family, :key => :id

    one_to_many :scenario, :key => [:tln_id, :network_family_id]

    many_to_one :parent,      :class => self, :key => [:network_id, :parent_id]
    one_to_many :subnetworks, :class => self, :key => [:network_id, :parent_id]
    
    one_to_many :nodes,   :key => [:network_id, :parent_id]
    one_to_many :links,   :key => [:network_id, :parent_id]
    one_to_many :sensors, :key => [:network_id, :parent_id]
    one_to_many :routes,  :key => [:network_id, :parent_id]
  end
end
