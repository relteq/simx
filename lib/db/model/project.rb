module Aurora
  class Project
    one_to_many :scenarios
    one_to_many :networks

    def before_destroy
      scenarios.each do |scenario|
        scenario.destroy
      end
      ### destroy sets too, using network_id?
      networks.each do |network|
        network.destroy
      end
      super
    end
  end
end
