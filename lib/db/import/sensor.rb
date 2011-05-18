module Aurora
  class Sensor
    include Aurora
    
    def self.create_from_xml sensor_xml, ctx, parent
      create_with_id sensor_xml["id"], parent.network_id do |sensor|
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
      
      self.type       = sensor_xml["type"]
      self.link_type  = sensor_xml["link_type"]

      link_xml_ids = sensor_xml.xpath("links").text.split(",").map{|s|s.strip}
      
      if link_xml_ids.size > 1
        raise ImportError,
          "sensor table doesn't support multiple links per sensor"
      end

      link_xml_ids.each do |link_xml_id|
        self.link_id = ctx.get_link_id(link_xml_id)
      end
      
      self.parameters = sensor_xml.xpath("parameters").first

      sensor_xml.xpath("display_position/point").each do |point_xml|
        self.display_lat = Float(point_xml["lat"])
        self.display_lng = Float(point_xml["lng"])
      end

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

