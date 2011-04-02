require 'db/model/scenario'

require 'db/import/vehicle-type'
require 'db/import/network'

module Aurora
  class Scenario
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
  end
end
