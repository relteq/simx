module Aurora
  class Sensor
    include Aurora
    
    def self.create_from_xml sensor_xml, ctx, parent
      create_with_id sensor_xml["id"] do |sensor|
        if sensor.id
          SensorFamily[sensor.id] or
            SensorFamily.create {|sf| sf.id = sensor.id}
        else
          sf = sensor.sensor_family = SensorFamily.create
          ctx.sensor_family_id_for_xml_id[sensor_xml["id"]] = sf.id
        end
        
        sensor.parent = parent
        sensor.import_xml sensor_xml, ctx
      end
    end
    
    def import_xml sensor_xml, ctx
      descs = sensor_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")
      
      self.offset     = ctx.import_length(sensor_xml["offset_in_link"] || 0)
      self.length     = ctx.import_length(sensor_xml["length"] || 0)
      
      if sensor_xml["postmile"]
        self.postmile = ctx.import_length(sensor_xml["postmile"])
      end
      
      self.type       = sensor_xml["type"]
      self.link_type  = sensor_xml["link_type"]
      self.data_id    = sensor_xml["data_id"]
      self.parameters = sensor_xml["parameters"]
      self.vds        = sensor_xml["vds"]
      self.hwy_name   = sensor_xml["hwy_name"]
      self.hwy_dir    = sensor_xml["hwy_dir"]
      self.lanes      = sensor_xml["lanes"]
      
      link_xml_ids = sensor_xml.xpath("links").text.split(",").map{|s|s.strip}
      link_xml_ids.each do |link_xml_id|
        if link
          raise ImportError,
            "sensor table doesn't support multiple links per sensor"
        end
        self.link_id = ctx.get_link_id(link_xml_id)
      end

      self.display_lat = Float(sensor_xml["display_lat"])
      self.display_lng = Float(sensor_xml["display_lng"])

      sensor_xml.xpath("position/point").each do |point_xml|
        self.lat = Float(point_xml["lat"])
        self.lng = Float(point_xml["lng"])
        if point_xml["elevation"]
          self.elevation = Float(point_xml["elevation"])
        end
      end
    end
  end
end

