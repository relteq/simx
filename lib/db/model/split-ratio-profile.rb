module Aurora
  class SplitRatioProfile < Sequel::Model
    many_to_one :node
  end
end

