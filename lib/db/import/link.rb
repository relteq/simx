require 'db/model/link'

#require 'db/import/demand-profile'
#require 'db/import/capacity-profile'

module Aurora
  class Link
    def self.import_xml link_xml
      link = create
      
      link.name = link_xml["name"]
      link.type = link_xml["type"]
      link.lanes = Integer(link_xml["lanes"])
      link.length = Float(link_xml["length"])
      
      descs = link_xml.xpath("description").map {|desc| desc.text}
      link.description = descs.join("\n")
      
      begin_id = link_xml.xpath("begin").first["id"]
      end_id = link_xml.xpath("end").first["id"]
      
      begin_node = Node[:id => begin_id]
      end_node = Node[:id => end_id]
      
      begin_node.add_output link
      end_node.add_input link
      
      link.save
      link
    end
  end
end
