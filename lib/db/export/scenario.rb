require 'db/export/model'
require 'db/export/initial-condition-set'
require 'db/export/event_set'
require 'db/export/controller_set'
require 'db/export/split_ratio_profile_set'

module Aurora
  class Scenario
    def schema_version
      "1.0.2" ### should read this from xsd
    end
    
    def build_xml xml
      xml.scenario(:id => id,
                   :name => name,
                   :schemaVersion => schema_version) {

        xml.description description

        xml.settings {
          xml.units units
          xml.display_(:dt => dt, 
                      :timeInitial => begin_time,
                      :timeMax => begin_time + duration)
          xml.VehicleTypes {
            vehicle_types.each do |v|
              xml.vtype(:name => v.name, :weight => v.weight)
            end
          }
        }

        parts = [
#          network,
          ic_set, srp_set, cp_set, dp_set,
          event_set, ctrl_set
        ]
        
        parts.each do |part|
          part.build_xml(xml) if part
        end
      }
    end
  end
end
