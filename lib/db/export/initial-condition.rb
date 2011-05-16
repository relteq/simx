module Aurora
  class InitialCondition
    def build_xml(xml)
      xml.event(:link_id => link_id) do
        xml.text density
      end
    end
  end
end
