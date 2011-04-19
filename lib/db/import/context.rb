module Aurora
  # Exists during one scenario import operation.
  class ImportContext
    include Aurora

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
    
    # Keep track of begin and end nodes, ordinals, and weaving_factors
    # for each link listed (as an xml id) under the node.
    attr_reader :begin_for_link_xml_id
    attr_reader :end_for_link_xml_id

    def initialize scenario
      @scenario = scenario
      
      @tln_id_for_xml_id            = {}
      @network_family_id_for_xml_id = {}
      @node_family_id_for_xml_id    = {}
      @link_family_id_for_xml_id    = {}
      @sensor_family_id_for_xml_id  = {}
      @route_family_id_for_xml_id   = {}
      
      @begin_for_link_xml_id        = {}
      @end_for_link_xml_id          = {}
      
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
    
    # define this so that import_length and similar methods will work
    def units
      @units ||= scenario.units
    end
    
    public :import_length
  end
end
