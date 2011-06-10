module Aurora
  module Model
    def after_create
      auto_time_fields = [:created_at, :updated_at]
      auto_time_fields.each do |atf|
        if self.class.columns.include?(atf)
          self.update({atf => Time.now})
        end
      end
    end
  end
end
