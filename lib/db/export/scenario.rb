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
    module ScenarioBuilder
      def schema_version
        "1.0.14" ### should read this from xsd
      end

      def build_xml(xml, db = DB)
        attrs = {
          :id => id,
          :schemaVersion => schema_version
        }

        attrs[:name] = name unless !name or name.empty?

        xml.scenario(attrs) {
          xml.description description unless !description or description.empty?

          xml.settings {
            xml.units units
            xml.display_(:dt => "%d" % dt,
                         :timeout => 50, # default for optional attr
                         :timeInitial => "%d" % (begin_time||0),
                         :timeMax => "%d" % ((begin_time||0) + (duration||0)))
            xml.VehicleTypes {
              vehicle_types.each do |v|
                xml.vtype(:name => v.name, :weight => v.weight)
              end
            }
          }

          # Separated from parts to pass db argument
          network.build_xml(xml, db)

          parts = [
            initial_condition_set, split_ratio_profile_set,
            capacity_profile_set, demand_profile_set, event_set,
            controller_set
          ]

          parts.each do |part|
            part.build_xml(xml) if part
          end
        }
      end
    end

    class Dummy
      include ScenarioBuilder
      
      def to_xml(db = DB)
        builder = Nokogiri::XML::Builder.new do |xml|
          build_xml(xml, db)
        end
        builder.to_xml
      end
    end
    
    include ScenarioBuilder

    def self.export_and_store_on_s3(id, db = DB)
      dbweb_s3_bucket = ENV["DBWEB_S3_BUCKET"] || "relteq-uploads-dev"
      unless AWS::S3::Base.connected? 
        AWS::S3::Base.establish_connection!(
            :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
            :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
        )
      end

      scenario_xml = Scenario[id].to_xml(db)
      key = Digest::MD5.hexdigest(scenario_xml) + ".xml"
      exists =
        begin
          AWS::S3::S3Object.find key, dbweb_s3_bucket
          true
        rescue AWS::S3::NoSuchKey
          false
        end

      unless exists
        AWS::S3::S3Object.store key, scenario_xml, dbweb_s3_bucket, {} 
      end

      return AWS::S3::S3Object.url_for(key, dbweb_s3_bucket) 
    end
  end
end
