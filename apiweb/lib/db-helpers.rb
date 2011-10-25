helpers do
  def type_translator
    @type_translator ||= { 
      'event_set' => Aurora::EventSet,
      'capacity_profile_set' => Aurora::CapacityProfileSet,
      'split_ratio_profile_set' => Aurora::SplitRatioProfileSet,
      'demand_profile_set' => Aurora::DemandProfileSet,
      'controller_set' => Aurora::ControllerSet,
      'network' => Aurora::Network,
      'scenario'=> Aurora::Scenario 
    }
  end

  def s3
    unless @s3
      ## sync?
      data_dir = ENV["SIMX_DATA_DIR"]
      
      if ENV["SIMX_S3_MOCK"] == "true"
        require 'simx/s3-mock'
        @s3 = S3_Mock.new(
          :dir      => File.join(data_dir, "s3-mock", SIMX_S3_BUCKET),
          :url_base => "/file",
          :log      => LOGGER
        )

      else
        require 'simx/s3-aws'
        @s3 = S3_AWS.new(
          :creds => {
            :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
            :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
          },
          :bucket => SIMX_S3_BUCKET,
          :log    => LOGGER
        )
      end
    end
  end

  ### should have rekey option
  def import_xml xml_data
    ###
    [table, id]
  end

  # project_id can be nil
  def import_scenario_xml xml_data, project_id, options = {}
    scenario = Aurora::Scenario.create_from_xml(xml_data, options)
    network = scenario.network
    scenario.project_id = project_id
    network.project_id = project_id
    network.save
    scenario.save # note: this is a no-op if scenario.id == 0
    scenario
  end
  
  def export_scenario_xml scenario_id
    Aurora::Scenario[Integer(scenario_id)].to_xml
  rescue => e
    LOGGER.error "export_scenario_xml(#{scenario_id}): #{e}"
    nil
  end
  
  def export_network_xml network_id
    Aurora::Network[Integer(network_id)].to_xml
  rescue => e
    LOGGER.error "export_network_xml(#{network_id}): #{e}"
    nil
  end
  
  def export_wrapped_network_xml network_id
    nw_xml = export_network_xml(network_id)
    LOGGER.debug "nw_xml = #{nw_xml[0..200]}..."
    
    sc_xml = %{\
<?xml version="1.0" encoding="UTF-8"?>
<scenario id='0'>
  <description>Scenario generated for editing network</description>
  <settings>
    <units>US</units>
  </settings>
  #{nw_xml.sub(/.*/, "")}
</scenario>
}

    sc_xml
    
  rescue => e
    LOGGER.error "export_wrapped_network_xml(#{network_id}): #{e}"
    nil
  end
end
