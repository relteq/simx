module Aurora
  class Model < Sequel::Model; end
  
  class NetworkFamily < Model; end
  class NodeFamily < Model; end
  class LinkFamily < Model; end
  class RouteFamily < Model; end
  class SensorFamily < Model; end
  
  class Network < Model; end
  class Node < Model; end
  class Link < Model; end
  class Route < Model; end
  class Sensor < Model; end

  class Scenario < Model; end
  class VehicleType < Model; end
  class Tln < Model; end
  class Project < Model; end

  class SplitRatioProfileSet < Model; end
  class SplitRatioProfile < Model; end

  class CapacityProfileSet < Model; end
  class CapacityProfile < Model; end

  class DemandProfileSet < Model; end
  class DemandProfile < Model; end

  class InitialConditionSet < Model; end
  class InitialCondition < Model; end

  class EventSet < Model; end
  class Event < Model; end
  class NetworkEvent < Model; end
  class NodeEvent < Model; end
  class LinkEvent < Model; end

  class ControllerSet < Model; end
  class Controller < Model; end
  class NetworkController < Model; end
  class NodeController < Model; end
  class LinkController < Model; end
end

dir = File.expand_path(File.dirname(__FILE__))
models_rb = Dir[File.join(dir, "*.rb")]
models = models_rb.map {|s| File.basename(s, ".rb")}
models.each do |model|
  require File.join('db/model', model)
end

