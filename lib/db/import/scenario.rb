require 'db/model/scenario'

require 'db/import/vehicle-type'
require 'db/import/network'

module Aurora
  class Scenario
    def self.import_xml scenario_xml
      scenario = create

      scenario_xml.xpath("settings/VehicleTypes/vtype").each do |vtype|
        scenario.add_vehicle_type VehicleType.import_xml(vtype)
      end

      scenario_xml.xpath("network").each do |network_xml|
        network = Network.import_xml(network_xml)
        network.add_scenario scenario
      end
      
      scenario.save
      scenario
    end
  end
end
