module Aurora
  class InitialCondition
    def build_xml(xml)
      xml.density(:link_id => link_id) do
        xml.text density
      end
    end
  end
end
