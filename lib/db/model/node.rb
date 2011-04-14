module Aurora
  class Node < Sequel::Model
    many_to_one :network
    one_to_many :splitratio_profiles
    
    one_to_many :outputs, :class => "Aurora::Link", :key => :begin_id
    one_to_many :inputs,  :class => "Aurora::Link", :key => :end_id
  end
end
