module Aurora
  module Model
    def shallow_copy(db=DB, overrides = {})
      puts overrides.inspect
      me_copy = self.class.new
      v = self.values.clone 
      v.delete :id
      v.merge! overrides
      me_copy.set(v)
      me_copy.name = '*' + me_copy.name unless overrides[:name]
      me_copy.save

      if(respond_to?(:shallow_copy_children) &&
         respond_to?(:shallow_copy_parent_field))
        sc_children = shallow_copy_children
        set_field = shallow_copy_parent_field
        sc_children.each do |child|
          child_copy = child.copy
          child_copy.set(set_field => me_copy.id)
          child_copy.save
        end
      else
        puts me_copy.class
      end

      return me_copy
    end
  end # a place to put things, e.g. in export/model.rb
  
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

