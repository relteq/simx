require 'db/export/controller_set'
require 'db/export/event_set'
require 'db/export/split_ratio_profile_set'

module Aurora
  class Scenario
    def to_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.scenario(:id => self.id, :name => self.name) {
          xml.settings {
            xml.units self.units
            xml.display_(:dt => self.dt, 
                        :timeInitial => self.begin_time,
                        :timeMax => self.begin_time + self.duration)
            xml.VehicleTypes {
              self.vehicle_types.each do |v|
                xml.vtype(:name => v.name, :weight => v.weight)
              end
            }
            SplitRatioProfileSet[self.srp_set_id].to_xml(xml)
            ControllerSet[self.ctrl_set_id].to_xml(xml)
            EventSet[self.event_set_id].to_xml(xml)
          }
        }
      end
      builder.to_xml
    end
  end
end
