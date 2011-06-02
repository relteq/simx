module Aurora
  module Model; end # a place to put things, e.g. in export/model.rb
  
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

  class Scenario < Sequel::Model; end
  class VehicleType < Sequel::Model; end
  class Tln < Sequel::Model; end
  class Project < Sequel::Model; end

  class SplitRatioProfileSet < Sequel::Model; end
  class SplitRatioProfile < Sequel::Model; end

  class CapacityProfileSet < Sequel::Model; end
  class CapacityProfile < Sequel::Model; end

  class DemandProfileSet < Sequel::Model; end
  class DemandProfile < Sequel::Model; end

  class InitialConditionSet < Sequel::Model; end
  class InitialCondition < Sequel::Model; end

  class EventSet < Sequel::Model; end
  class Event < Sequel::Model; end
  class NetworkEvent < Event; end
  class NodeEvent < Event; end
  class LinkEvent < Event; end

  class ControllerSet < Sequel::Model; end
  class Controller < Sequel::Model; end
  class NetworkController < Controller; end
  class NodeController < Controller; end
  class LinkController < Controller; end
  
  constants.each do |const|
    c = const_get(const)
    if c.kind_of? Class and c < Sequel::Model
      c.class_eval do
        include Aurora::Model
      end
    end
  end
end

dir = File.expand_path(File.dirname(__FILE__))
models_rb = Dir[File.join(dir, "*.rb")]
models = models_rb.map {|s| File.basename(s, ".rb")}
models.each do |model|
  require File.join('db/model', model)
end

