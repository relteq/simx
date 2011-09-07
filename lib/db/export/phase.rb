module Aurora
  class Phase
    def build_xml(xml)
      xml.phase(
        :nema           => nema,
        
        :yellow_time    => yellow_time,
        :red_clear_time => red_clear_time,
        :min_green_time => min_green_time,
        
        :protected      => self.protected,
        :permissive     => permissive,
        :lag            => lag,
        :recall         => recall
      ) {
        xml.links {
          xml.text links.map {|link| link.id}.join(",")
        }
      }
    end
  end
end
