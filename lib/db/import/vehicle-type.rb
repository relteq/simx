require 'db/model/vehicle-type'

module Aurora
  class VehicleType
    def self.from_xml vtype_xml, scenario
      vt = create
      vt.import_xml vtype_xml, scenario
      vt.save
      vt
    end

    def import_xml vtype_xml, scenario
      self.name   = vtype_xml["name"]
      self.weight = Float(vtype_xml["weight"])
    end
  end
end
