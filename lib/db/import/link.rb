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
      self.name = link_xml["name"]
      self.type = link_xml["type"]
      self.lanes = Integer(link_xml["lanes"])
      self.length = Float(link_xml["length"])
      
      descs = link_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      begin_id = link_xml.xpath("begin").first["node_id"]
      end_id = link_xml.xpath("end").first["node_id"]
      
      ### need to apply id translation
      begin_node = Node[:id => begin_id]
      end_node = Node[:id => end_id]
      
      begin_node.add_output self
      end_node.add_input self
    end
  end
end
