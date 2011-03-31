require 'db/model/vehicle-type'

module Aurora
  class VehicleType
    def self.import_xml vtype_xml
      create(
        :name   => vtype_xml["name"],
        :weight => Float(vtype_xml["weight"])
      )
    end
  end
end
