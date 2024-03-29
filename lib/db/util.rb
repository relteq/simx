require 'sequel'

module Aurora
  module_function
  
  UNITS             = %w{ US Metric }
  NODE_TYPES        = %w{ F H S P O T }
  LINK_TYPES        = %w{ FW HW HOV HOT HV ETC OR FR IC ST LT RT D }
  SENSOR_TYPES      = %w{ loop radar camera sensys }
  SENSOR_LINK_TYPES = %w{ ML HV OR FR }
  EVENT_TYPES       = %w{ FD DEMAND QLIM SRM WFM SCONTROL NCONTROL CCONTROL
                          TCONTROL MONITOR }
  CONTROLLER_TYPES  = %w{ ALINEA TOD TR VSLTOD SIMPLESIGNAL PRETIMED ACTUADED
                          SYNCHRONIZED SWARM HERO SLAVE }
  QCONTROLLER_TYPES = %w{ QUEUEOVERRIDE PROPORTIONAL PI }
  DYNAMICS          = %w{ CTM }
  EVENT_STI_TYPES   = %w{ LinkEvent NodeEvent NetworkEvent }
  CONTROL_STI_TYPES = %w{ NetworkController NodeController LinkController }

  # Convert length in xml file to length for insertion in database.
  def import_length len
    len = Float(len)
    case units
    when "US"
      len
    when "Metric"
      len * 0.62137119 # km to miles
    else
      raise "Bad units: #{units.inspect}"
    end
  end

  # Convert speed in xml file to speed for insertion in database.
  def import_speed spd
    spd = Float(spd)
    case units
    when "US"
      spd
    when "Metric"
      spd * 0.62137119 # kph to mph
    else
      raise "Bad units: #{units.inspect}"
    end
  end

  # Convert density in xml file to density for insertion in database.
  def import_density den
    den = Float(den)
    case units
    when "US"
      den
    when "Metric"
      den * 1.609344 # v/km to v/mile
    else
      raise "Bad units: #{units.inspect}"
    end
  end
  
  def import_boolean s, *default
    case s
    when "true"; true
    when "false"; false
    when nil
      if default.empty?
        raise "Bad boolean: #{s.inspect}"
      else
        default.first
      end
    else raise "Bad boolean: #{s.inspect}"
    end
  end
  
  # If string is not a valid name, defers setting the name from the id
  # until after the first pass through the importer.
  def set_name_from s, ctx
    case s
    when /\S/
      self.name = s
    else
      ctx.defer do
        cl_name = self.class.name[/\w+$/]
        self.update(:name => "#{cl_name} #{id}")
      end
    end
  end
  
  def included m
    if m < Sequel::Model
      m.extend AuroraModelClassMethods
    end
  end

  def import_id s ##
    id = (s && Integer(s) rescue nil)
    id = nil if id && id <= 0
    id
  end
end

module AuroraModelClassMethods
  def import_id s
    id = (s && Integer(s) rescue nil)
    id = nil if id && id <= 0
    id
  end
  
  # Creates and return an instance with ID parsed from s. If s is not
  # parsable as a positive integer, the instance will be assigned a new id.
  # Yields model to block in the context of create, after id assigned:
  #
  #  create_with_id s do |model|
  #    model.name = "foo_#{model.id}"
  #  end
  #
  # Returns model.
  #
  # If the model already exists, yield and return it.
  #
  def create_with_id s, network_id = nil
    id = import_id(s)
    
    if id
      model =
        network_id ?
          self[:id => id, :network_id => network_id] :
          self[:id => id]
    end

    if model
      if block_given?
        yield model
        model.save_changes
      end
      model
    
    else
      create do |model|
        model.id = id if id
        yield model if block_given?
      end
    end
  end
end
