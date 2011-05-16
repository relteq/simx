module Aurora
  class CapacityProfile
    def build_xml(xml)
      xml.event(
        :link_id => link_id,
        :start_time => start_time,
        :dt => dt
      ) do
        xml.text profile
      end
    end
  end
end
