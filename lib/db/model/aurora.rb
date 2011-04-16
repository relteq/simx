module Aurora
  class NetworkFamily < Sequel::Model; end
  class NodeFamily < Sequel::Model; end
  class LinkFamily < Sequel::Model; end
  class RouteFamily < Sequel::Model; end
  class SensorFamily < Sequel::Model; end
  
  class Network < Sequel::Model; end
  class Node < Sequel::Model; end
  class Link < Sequel::Model; end
  class Route < Sequel::Model; end
  class Sensor < Sequel::Model; end

  class Scenario < Sequel::Model
  class VehicleType < Sequel::Model
  class Tln < Sequel::Model
  class Project < Sequel::Model

  class SplitRatioProfileSet < Sequel::Model
  class SplitRatioProfile < Sequel::Model

  class CapacityProfileSet < Sequel::Model
  class CapacityProfile < Sequel::Model

  class DemandProfileSet < Sequel::Model
  class DemandProfile < Sequel::Model

  class InitialConditionSet < Sequel::Model
  class InitialCondition < Sequel::Model

  class EventSet < Sequel::Model
  class Event < Sequel::Model
  class NetworkEvent < Sequel::Model
  class NodeEvent < Sequel::Model
  class LinkEvent < Sequel::Model

  class ControllerSet < Sequel::Model
  class Controller < Sequel::Model
  class NetworkController < Sequel::Model
  class NodeController < Sequel::Model
  class LinkController < Sequel::Model
end

dir = File.expand_path(File.dirname(__FILE__))
models_rb = Dir[File.join(dir, "*.rb")]
models = models_rb.map {|s| File.basename(s, ".rb")}
models.each do |model|
  require File.join('db/model', model)
end

