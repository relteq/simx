module Aurora
  class SplitRatioProfile
    def build_xml(xml)
      xml.event(
        :node_id => node_id,
        :start_time => start_time,
        :dt => dt
      ) do
        xml << profile
      end
    end
  end
end
