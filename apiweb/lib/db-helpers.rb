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
    @s3 ||= begin
      ## sync?
      data_dir = ENV["SIMX_DATA_DIR"]
      
      if ENV["SIMX_S3_MOCK"] == "true"
        require 'simx/s3-mock'
        S3_Mock.new(
          :dir      => File.join(data_dir, "s3-mock", SIMX_S3_BUCKET),
          :url_base => "/file",
          :log      => log
        )

      else
        require 'simx/s3-aws'
        S3_AWS.new(
          :creds => {
            :access_key_id     => ENV["AMAZON_ACCESS_KEY_ID"],
            :secret_access_key => ENV["AMAZON_SECRET_ACCESS_KEY"]
          },
          :bucket => SIMX_S3_BUCKET,
          :log    => log
        )
      end
    end
  end
  
  # temp file storage, accessible thru apiweb, using s3-mock;
  # replaces s3 for short-term storage
  def webtmp
    @webtmp ||= begin
      require 'simx/s3-mock'

      data_dir = ENV["SIMX_DATA_DIR"]
      
      S3_Mock.new(
        :dir      => File.join(data_dir, "webtmp"),
        :url_base => "/tmp",
        :log      => log
      )
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

    if !project_id
      sc = DB[:scenarios][:id => scenario.id]
      if sc
        project_id = sc[:project_id]
      end
    end

    scenario.project_id = project_id
    network.project_id = project_id
    network.save
    scenario.save # note: this is a no-op if scenario.id == 0
    scenario
  end
  
  def export_scenario_xml scenario_id
    Aurora::Scenario[Integer(scenario_id)].to_xml
  rescue => e
    log.error "export_scenario_xml(#{scenario_id}): #{e}"
    nil
  end
  
  def export_network_xml network_id
    Aurora::Network[Integer(network_id)].to_xml
  rescue => e
    log.error "export_network_xml(#{network_id}): #{e}"
    nil ### fix this error handling
  end
  
  def export_wrapped_network_xml network_id
    nw_xml = export_network_xml(network_id)
    log.debug "nw_xml = #{nw_xml[0..200]}..."
    
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
    log.error "export_wrapped_network_xml(#{network_id}): #{e}"
    nil ### fix this error handling
  end
  
  def apiweb_key_table_exists!
    DB.create_table? :apiweb_key do
      text          :key,         :primary_key => true, :null => false
      text          :model_class, :null => false
      integer       :model_id,    :null => false
      integer       :project_id
      integer       :user_id
      timestamp     :expiration,  :null => false
    end
  end
  
  # +entry+ should have :model_class and :model_id; may have
  # :project_id, :user_id, :expiration. Returns the key.
  # All values in the hash are used in constructing the key,
  # so for example: entry[:token] = access_token.
  def request_apiweb_key entry = {}
    apiweb_key_table_exists!
    
    entry[:expiration] ||= Time.now + 24*60*60 ## ?
    
    fields = DB.schema(:apiweb_key).map {|a|a.first}
    
    i = 0
    loop do
      i += 1
      key = digest(Time.now.to_f + i, *entry.values)
      
      if not DB[:apiweb_key][:key => key]
        entry[:key] = key
        
        e = {}
        fields.each do |field|
          e[field] = entry[field]
        end
        
        DB[:apiweb_key].insert e
        return key
      end
    end
  end
  
  # Returns the entry that was stored with the +key+, but only
  # if the key has not expired.
  def lookup_apiweb_key key
    apiweb_key_table_exists!
    
    entry = DB[:apiweb_key][:key => key]
    ## check project_id and user_id
    
    if Time.now > entry[:expiration]
      ## remove the entry?
      return nil ## what effect does this have on the client side?
    end
    
    entry
  end
end
