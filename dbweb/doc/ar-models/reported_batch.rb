class ReportedBatch < ActiveRecord::Base
  belongs_to :simulation_batch
  belongs_to :simulation_batch_list
end
