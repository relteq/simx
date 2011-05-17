module Aurora
  class SplitRatioProfile
    def build_xml(xml)
      attrs = {
        :node_id => node_id,
        :dt => dt
      }
      
      attrs[:start_time] = start_time if start_time != 0

      xml.splitratios(attrs) do
        xml << profile
      end
    end
  end
end
