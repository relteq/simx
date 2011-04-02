require 'db/model/scenario'

require 'db/import/vehicle-type'
require 'db/import/network'

### use timestamp plugin

module Aurora
  class Scenario
    # Translation tables from xml ID to database ID.
    attr_reader :network_id_for_xml_id
    attr_reader :sensor_id_for_xml_id
    attr_reader :monitor_id_for_xml_id
    attr_reader :node_id_for_xml_id
    attr_reader :link_id_for_xml_id
    
    def initialize(*)
      super
      @network_id_for_xml_id  = {}
      @sensor_id_for_xml_id   = {}
      @monitor_id_for_xml_id  = {}
      @node_id_for_xml_id     = {}
      @link_id_for_xml_id     = {}
    end
    
    def self.from_xml scenario_xml
      scenario = create
      scenario.import_xml scenario_xml
      scenario.save
      scenario
    end
    
    def import_xml scenario_xml
      scenario_xml.xpath("settings/VehicleTypes/vtype").each do |vtype_xml|
        add_vehicle_type VehicleType.from_xml(vtype_xml, self)
      end
      
      scenario_xml.xpath("settings/units").each do |units|
        self.units = units.text # US or Metric
      end

      scenario_xml.xpath("network").each do |network_xml|
        network = Network.from_xml(network_xml, self)
        network.add_scenario self
      end
    end

    # Convert length in xml file to length for insertion in database.
    def import_length len
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
      case units
      when "US"
        den
      when "Metric"
        den * 1.609344 # v/km to v/mile
      else
        raise "Bad units: #{units}"
      end
    end
  end
end
