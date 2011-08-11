module Aurora
  class SimulationBatchReport
    def s3_xml
      require 'aws/s3'
      unless AWS::S3::Base.connected? 
        AWS::S3::Base.establish_connection!(
          :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
          :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
        )
      end
      AWS::S3::S3Object.value xml_key, s3_bucket
    end
  end
end
