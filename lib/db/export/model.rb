require 'nokogiri'

module Aurora
  module Model
    def to_xml(db = DB)
      builder = Nokogiri::XML::Builder.new do |xml|
        build_xml(xml, db)
      end
      builder.to_xml
    end
  end
end
