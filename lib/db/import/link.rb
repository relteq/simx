require 'db/model/link'

module Aurora
  class Link
    include Aurora
    
    def self.from_xml link_xml, scenario
      link = import_network_element_id(link_xml["id"], scenario.network)
      link.import_xml link_xml, scenario
      link.save
      link
    end
    
    def import_xml link_xml, scenario
      scenario.link_id_for_xml_id[link_xml["id"]] = id

      ### subnetwork_id

      self.name = link_xml["name"]

      descs = link_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      self.lanes = Integer(link_xml["lanes"])
      self.length = import_length(link_xml["length"])
      self.type = link_xml["type"]
      
      link_xml.xpath("fd").each do |fd_xml|
        # just store the xml in the column for now
        self.fd = Float(fd_xml)
      end
      link_xml.xpath("qmax").each do |qmax_xml|
        self.qmax = Float(qmax_xml.text)
      end
      link_xml.xpath("dynamics").each do |dynamics_xml|
        self.dynamics = Float(dynamics_xml.text)
      end
      
      begin_id_xml = link_xml.xpath("begin").first["node_id"]
      end_id_xml = link_xml.xpath("end").first["node_id"]
      
      ## replace with custom associations
      self.begin_id = scenario.node_id_for_xml_id[begin_id_xml]
      self.end_id = scenario.node_id_for_xml_id[end_id_xml]
      
      #begin_node = Node[                         
      #  :network_id => scenario.network.id,      
      #  :id => begin_id                          
      #]                                          
      #end_node = Node[                           
      #  :network_id => scenario.network.id,      
      #  :id => end_id                            
      #]                                          

      peer_output_ids = scenario.output_link_ids_for_node_id[begin_id]
      peer_input_ids = scenario.input_link_ids_for_node_id[end_id]
      wfs = scenario.weaving_factors_for_node_id[end_id]
      
      self.begin_order = peer_output_ids.index(id)
      self.end_order = peer_input_ids.index(id)
      self.weaving_factors = wfs[end_order]
    end
  end
end
