require 'db/export/model'
require 'db/export/network'
require 'db/export/event-set'
require 'db/export/controller-set'
require 'db/export/initial-condition-set'
require 'db/export/split-ratio-profile-set'
require 'db/export/capacity-profile-set'
require 'db/export/demand-profile-set'

module Aurora
  class Scenario
    def schema_version
      "1.0.5" ### should read this from xsd
    end
    
    def build_xml xml
      attrs = {
        :id => id,
        :schemaVersion => schema_version
      }
      
      attrs[:name] = name unless !name or name.empty?
      
      xml.scenario(attrs) {
        xml.description description unless !description or description.empty?

        xml.settings {
          xml.units units
          xml.display_(:dt => dt,
                       :timeout => 50, # default for optional atr
                       :timeInitial => begin_time,
                       :timeMax => begin_time + duration)
          xml.VehicleTypes {
            vehicle_types.each do |v|
              xml.vtype(:name => v.name, :weight => v.weight)
            end
          }
        }

        parts = [
          network, initial_condition_set, split_ratio_profile_set, 
          capacity_profile_set, demand_profile_set, event_set, 
          controller_set
        ]
        
        parts.each do |part|
          part.build_xml(xml) if part
        end
      }
    end
  end
end
