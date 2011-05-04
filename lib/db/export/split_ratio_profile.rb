module Aurora
  class SplitRatioProfile
    def to_xml(xml)
      xml.splitratios(:node_id => self.node_id, :dt => self.dt) {
        xml << self.profile
      }
    end
  end
end
