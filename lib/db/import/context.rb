module Aurora
  # Exists during one scenario import operation.
  class ImportContext
    # The scenario being imported.
    attr_reader :scenario
    
    # Translation tables from xml ID to database ID.
    # These are only needed when the xml ID is non-numeric. Numeric IDs
    # go directly into the database without translation.
    attr_reader :tln_id_for_xml_id
    attr_reader :network_family_id_for_xml_id
    attr_reader :node_family_id_for_xml_id
    attr_reader :link_family_id_for_xml_id
    attr_reader :route_family_id_for_xml_id
    attr_reader :sensor_family_id_for_xml_id
    
    # Keep track, during import, of order of links in input and output lists
    # and the list of weaving_factors corresponding to input links. The key
    # is always the db id, not the xml id.
    attr_reader :output_link_ids_for_node_id
    attr_reader :input_link_ids_for_node_id
    attr_reader :weaving_factors_for_node_id

    def initialize scenario
      @scenario = scenario
      
      @tln_id_for_xml_id            = {}
      @network_family_id_for_xml_id = {}
      @node_family_id_for_xml_id    = {}
      @link_family_id_for_xml_id    = {}
      @sensor_family_id_for_xml_id  = {}
      @route_family_id_for_xml_id   = {}
      
      @output_link_ids_for_node_id  = {}
      @input_link_ids_for_node_id   = {}
      @weaving_factors_for_node_id  = {}
      
      @deferred = []
    end
    
    def defer &action
      @deferred << action
    end
    
    def do_deferred
      while action = @deferred.shift
        action.call
      end
    end
  end
end
