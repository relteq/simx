module Aurora
  class Link
    def build_xml(xml)
      xml.link(:id => id, :name => name, :type => self[:type]) {
        xml.description description unless description.empty?
      }
    end
  end
end
