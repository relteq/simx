class SimulationBatch < ActiveRecord::Base
  has_many :scenarios
  
  belongs_to :output_file
  
  has_many :reported_batches
  has_many :simulation_batch_lists, :through => :reported_batches
  
end
