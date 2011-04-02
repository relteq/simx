class SimulationBatchList < ActiveRecord::Base
  belongs_to :simulation_batch_report
  
  has_many :reported_batches
  has_many :simulation_batches, :through => :reported_batches
  
end
