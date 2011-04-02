class NetworkNode < ActiveRecord::Base
  belongs_to :network
  belongs_to :node
end
