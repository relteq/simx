module Aurora
  class VehicleType
    def self.create_from_xml vtype_xml, ctx
      create do |vtype|
        vtype.scenario = ctx.scenario
        vtype.import_xml vtype_xml, ctx
      end
    end

    def import_xml vtype_xml, ctx
      self.name   = vtype_xml["name"]
      self.weight = Float(vtype_xml["weight"])
    end
  end
end
