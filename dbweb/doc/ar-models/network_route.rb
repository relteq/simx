class NetworkRoute < ActiveRecord::Base
  belongs_to :network
  belongs_to :route
end
