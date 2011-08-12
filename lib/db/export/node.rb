module Aurora
  class Node
    def build_xml(xml)
      xml.node(:id => id, :name => name, :type => type_node, :lock => lock) {
        xml.description description unless !description or description.empty?
        
        #unless outputs.empty? # xsd doesn't like this
          outputs_in_order = outputs.sort_by {|output| output.begin_order}
          xml.outputs {
            outputs_in_order.each do |output|
              xml.output(:link_id => output.id)
            end
          }
        #end
        
        #unless inputs.empty?
          inputs_in_order = inputs.sort_by {|input| input.end_order}
          xml.inputs {
            inputs_in_order.each do |input|
              xml.input(:link_id => input.id) {
                wf = input.weaving_factors
                xml << wf if wf
              }
            end
          }
        #end
        
        xml.position {
          point_attrs = {
            :lat => lat,
            :lng => lng
          }
          point_attrs[:elevation] = elevation if elevation != 0
          xml.point point_attrs
        }
      }
    end
  end
end
