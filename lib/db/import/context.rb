require 'db/util'

module Aurora
  class ImportError < StandardError; end
  
  # Exists during one scenario import operation.
  class ImportContext
    include Aurora

    # The scenario being imported.
    attr_reader :scenario
    
    # Translation tables from xml ID to database ID.
    # These are only needed when the xml ID is non-numeric or negative.
    # Positive numeric IDs go directly into the database without translation.
    attr_reader :network_id_for_xml_id
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
      
      @network_id_for_xml_id        = {}
      
      @node_family_id_for_xml_id    = {}
      @link_family_id_for_xml_id    = {}
      @sensor_family_id_for_xml_id  = {}
      @route_family_id_for_xml_id   = {}
      
      @begin_for_link_xml_id        = {}
      @end_for_link_xml_id          = {}
      
      @deferred = []
    end
    
    # Returns the network ID for the network specified in
    # the given string. If the string is not a decimal integer, look up the
    # string in the hash of local IDs defined in the imported xml.
    def get_network_id network_xml_id
      network_xml_id or raise ArgumentError
      network_id_for_xml_id[network_xml_id] || Integer(network_xml_id)
    rescue ArgumentError
      raise ImportError, "invalid network id: #{network_xml_id.inspect}"
    end
    
    # Returns the node family ID for the node specified in the given
    # string. If the string is not a decimal integer, look up the string
    # in the hash of local IDs defined in the imported xml.
    def get_node_id node_xml_id
      node_xml_id or raise ArgumentError
      node_family_id_for_xml_id[node_xml_id] || Integer(node_xml_id)
    rescue ArgumentError
      raise ImportError, "invalid node id: #{node_xml_id.inspect}"
    end
    
    # Returns the link family ID for the link specified in the given
    # string. If the string is not a decimal integer, look up the string
    # in the hash of local IDs defined in the imported xml.
    def get_link_id link_xml_id
      link_xml_id or raise ArgumentError
      link_family_id_for_xml_id[link_xml_id] || Integer(link_xml_id)
    rescue ArgumentError
      raise ImportError, "invalid link id: #{link_xml_id.inspect}"
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
