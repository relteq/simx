require 'nokogiri'

module Aurora
  module Model
    def to_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        build_xml(xml)
      end
      builder.to_xml
    end
  end
end
