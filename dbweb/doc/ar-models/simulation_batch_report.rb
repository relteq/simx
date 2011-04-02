class SimulationBatchReport < ActiveRecord::Base
  has_many :simlulation_batch_lists
  
  belongs_to :scatter_plot
  belongs_to :color_pallette
  
end
