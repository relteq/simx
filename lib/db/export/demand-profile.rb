module Aurora
  class DemandProfile
    def build_xml(xml)
      attrs = {
        :link_id => link_id,
        :dt => dt,
        :knob => 1.0 ## tmp until added to db schema
      }
      
      attrs[:start_time] = start_time if start_time != 0

      xml.demand(attrs) do
        xml.text profile
      end
    end
  end
end
