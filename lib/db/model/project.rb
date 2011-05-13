module Aurora
  class Project
    one_to_many :scenarios
    one_to_many :tlns

    def before_destroy
      scenarios.each do |scenario|
        scenario.destroy
      end
      tlns.each do |tln|
        tln.destroy
      end
      super
    end
  end
end
