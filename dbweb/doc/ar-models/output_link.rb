class OutputLink < ActiveRecord::Base
  belongs_to :link
  belongs_to :node
  belongs_to :network
  
end
