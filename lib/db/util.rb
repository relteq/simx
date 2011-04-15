def create_table? t, db = DB, &bl
  db.table_exists? t or db.create_table t, &bl
end

# Used to generate IDs that are unique across all tables that use it.
# The tables include all those with composite primary key (node, link...).
# All rows but the last can be deleted at any time.
# Distinctly created (not copied) entities remain distinct
# in the database, so that they can be copied and pasted alongside
# each other. See AuroraModelClassMethods#get_uniq_id.
def create_next_uniq_id_table db = DB ## obsolete
  create_table? :next_uniq_id, db do
    primary_key :id
  end
end

module Aurora
  module_function
  
  UNITS             = %w{ US Metric }
  NODE_TYPES        = %w{ F H S P O T }
  LINK_TYPES        = %w{ FW HW HOV HOT HV ETC OR FR IC ST D }
  SENSOR_TYPES      = %w{ loop radar camera sensys }
  SENSOR_LINK_TYPES = %w{ ML HV OR FR }
  EVENT_TYPES       = %w{ FD DEMAND QLIM SRM WFM SCONTROL NCONTROL CCONTROL
                          TCONTROL MONITOR }
  CONTROLLER_TYPES  = %w{ ALINEA TOD TR VSLTOD SIMPLESIGNAL PRETIMED ACTUADED
                          SYNCHRONIZED SWARM HERO SLAVE }
  QCONTROLLER_TYPES = %w{ QUEUEOVERRIDE PROPORTIONAL PI }
  DYNAMICS          = %w{ CTM }

  # Convert length in xml file to length for insertion in database.
  def import_length len
    len = Float(len)
    case units
    when "US"
      len
    when "Metric"
      len * 0.62137119 # km to miles
    else
      raise "Bad units: #{units}"
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
      raise "Bad units: #{units}"
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
      raise "Bad units: #{units}"
    end
  end
  
  def import_boolean s
    case s
    when "true"; true
    when "false"; false
    else raise "Bad boolean: #{s.inspect}"
    end
  end
  
  def included m
    if m < Sequel::Model
      m.extend AuroraModelClassMethods
    end
  end
end

module AuroraModelClassMethods
  # Creates and return an instance with ID parsed from s. If s is not
  # parsable as an integer, the instance will be assigned a new id.
  # Yields model to block in the context of create, after id assigned:
  #
  #  import_id s do |model|
  #    model.name = "foo_#{model.id}"
  #  end
  #
  def import_id s
    unless s and /\S/ === s
      raise "#{self}: missing id attr" ## InvalidXmlError ?
    end

    id = (Integer(s) rescue nil)

    begin
      create do |model|
        model.id = id
        yield model if block_given?
      end
    rescue Sequel::DatabaseError ## or should we just assume transaction?
      if self[:id => id] ### :network_id too?
        raise "#{self} already exists" ### delete and insert
      else
        raise
      end
    end
  end
  
  # As import_id, but for nodes, links, etc. Assigns the (network_id, id)
  # composite primary key. The +network+ must be the top level network
  # that contains the new model element.
  def import_network_element_id s, network
    import_id s do |model|
      model.network_id = network.network_id
      model.id ||= get_uniq_id # autoincrement doesn't work on composite key
    end
  end

  def get_uniq_id db = DB ## obsolete
    uniq_id = db[:next_uniq_id].insert
    db[:next_uniq_id].where(:id => uniq_id - 1).delete
    uniq_id
  end
end
