module Aurora
  class Phase
    include Aurora
    
    def self.create_from_xml phase_xml, ctx, signal
      create do |phase|
        phase.signal = signal
        phase.import_xml phase_xml, ctx
      end
    end
    
    def import_xml phase_xml, ctx
      self.nema = Integer(phase_xml["nema"])
      
      self.yellow_time    = Float(phase_xml["yellow_time"])
      self.red_clear_time = Float(phase_xml["red_clear_time"])
      self.min_green_time = Float(phase_xml["min_green_time"])

      self.protected      = import_boolean(phase_xml["protected"])
      self.permissive     = import_boolean(phase_xml["permissive"])
      self.lag            = import_boolean(phase_xml["lag"])
      self.recall         = import_boolean(phase_xml["recall"])
      
      ctx.defer do # the phase doesn't exist yet
        phase_xml.xpath("links").each do |links_xml|
          links_xml.text.split(",").map{|s|s.strip}.each do |link_xml_id|
          self.class.db[:phase_links] << {
            :phase_id   => id,
            :network_id => signal.network_id,
            :link_id    => ctx.get_link_id(link_xml_id)
          }
          end
        end
      end
    end
  end
end
