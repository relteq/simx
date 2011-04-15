module Aurora
  # For testing, this is a stub.
  class Project < Sequel::Model
    one_to_many :scenarios
  end
end

