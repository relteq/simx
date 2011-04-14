require 'db/model/scenario'
require 'db/util'

require 'db/import/vehicle-type'
require 'db/import/network'

module Aurora
  class Scenario
    include Aurora
    
    # Translation tables from xml ID to database ID.
    # These are only needed when the xml ID is non-numeric.
    attr_reader :network_id_for_xml_id
    attr_reader :node_id_for_xml_id
    attr_reader :link_id_for_xml_id
    attr_reader :sensor_id_for_xml_id
    attr_reader :monitor_id_for_xml_id
    ## more of these... ODs? Routes?
    
    # Keep track, during import, of order of links in input and output lists
    # and the list of weaving_factors corresponding to input links. The key
    # is always the db id, not the xml id.
    attr_reader :output_link_ids_for_node_id
    attr_reader :input_link_ids_for_node_id
    attr_reader :weaving_factors_for_node_id
    
    def init_import_state
      @network_id_for_xml_id  = {}
      @node_id_for_xml_id     = {}
      @link_id_for_xml_id     = {}
      @sensor_id_for_xml_id   = {}
      @monitor_id_for_xml_id  = {}
      
      @output_link_ids_for_node_id  = {}
      @input_link_ids_for_node_id   = {}
      @weaving_factors_for_node_id  = {}
    end
    
    def self.from_xml scenario_xml
      scenario = import_id(scenario_xml["id"])
      scenario.import_xml scenario_xml
      scenario.save
      scenario
    end
    
    def import_xml scenario_xml
      init_import_state
      
      self.name = scenario_xml["name"]

      descs = node_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      scenario_xml.xpath("settings/VehicleTypes/vtype").each do |vtype_xml|
        add_vehicle_type VehicleType.from_xml(vtype_xml, self)
      end
      
      scenario_xml.xpath("settings/units").each do |units_xml|
        self.units = units_xml.text # US or Metric
      end
      
      scenario_xml.xpath("settings/display").each do |display_xml|
        self.dt = Float(display_xml["dt"])
        
        self.begin_time = Float(display_xml["timeInitial"] || 0.0)
        self.duration = Float(display_xml["timeMax"]) - begin_time
      end

      scenario_xml.xpath("network").each do |network_xml|
        self.network = Network.from_xml(network_xml, self)
      end
      
      ### profiles, etc.
    end
  end
end
