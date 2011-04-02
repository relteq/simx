require 'db/model/link'

#require 'db/import/demand-profile'
#require 'db/import/capacity-profile'

module Aurora
  class Link
    def self.from_xml link_xml, scenario
      link = create
      link.import_xml link_xml, scenario
      link.save
      link
    end
    
    def import_xml link_xml, scenario
      scenario.link_id_for_xml_id[link_xml["id"]] = id

      self.name = link_xml["name"]
      self.type = link_xml["type"]
      self.lanes = Integer(link_xml["lanes"])
      self.length = scenario.import_length(Float(link_xml["length"]))
      
      descs = link_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      begin_id_xml = link_xml.xpath("begin").first["node_id"]
      end_id_xml = link_xml.xpath("end").first["node_id"]
      
      ## density units: use scenario.import_density
      
      begin_node = Node[:id => scenario.node_id_for_xml_id[begin_id_xml]]
      end_node = Node[:id => scenario.node_id_for_xml_id[end_id_xml]]
      
      begin_node.add_output self
      end_node.add_input self
    end
  end
end
