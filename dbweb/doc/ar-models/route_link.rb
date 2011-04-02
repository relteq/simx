class RouteLink < ActiveRecord::Base
  belongs_to :route
  belongs_to :link
end
