class NetworkFamily < ActiveRecord::Base
  belongs_to :network, :foreign_key => "network_id", :class_name => "Network"
  belongs_to :child, :foreign_key => "child_id", :class_name => "Network"
end
