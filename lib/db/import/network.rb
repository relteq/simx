require 'db/import/node'
require 'db/import/link'
require 'db/import/route'
require 'db/import/sensor'

module Aurora
  class Network
    include Aurora
    
    def self.create_from_xml network_xml, ctx, parent = nil
      create_with_id network_xml["id"] do |network|
        if network.id
          NetworkFamily[network.id] or
            NetworkFamily.create {|nf| nf.id = network.id}
        else
          nf = network.network_family = NetworkFamily.create
          ctx.network_family_id_for_xml_id[network_xml["id"]] = nf.id
        end
        
        if parent
          network.tln = parent.tln
          network.parent = parent

        else # this network "is" a tln
          network_id = import_id(network_xml["network_id"])

          if network_id
            tln = Tln[network_id]
            if not tln
              raise "xml specified nonexistent network_id: #{network_id}" ##
            end
            network.tln = tln
          
          else
            tln = network.tln = Tln.create
            ctx.tln_id_for_xml_id[network_xml["network_id"]] = tln.id
          end
          
          if ctx.scenario.tln and ctx.scenario.tln != network.tln
            raise "wrong tln"
          end
        end

        network.import_xml network_xml, ctx, parent
      end
    end
    
    def import_xml network_xml, ctx, parent = nil
      set_name_from network_xml["name"], ctx

      descs = network_xml.xpath("description").map {|desc| desc.text}
      self.description = descs.join("\n")

      self.dt           = Float(network_xml["dt"])
      self.ml_control   = import_boolean(network_xml["ml_control"])
      self.q_control    = import_boolean(network_xml["q_control"])

      network_xml.xpath("position/point").each do |point_xml|
        self.lat = Float(point_xml["lat"])
        self.lng = Float(point_xml["lng"])
        if point_xml["elevation"]
          self.elevation = Float(point_xml["elevation"])
        end
      end

      ctx.defer do
        [
          ["NodeList/node", Node],
          ["LinkList/link", Link],
          ["NetworkList/network", Network],
          ["ODList/od/PathList/path", Route],
          ["SensorList/sensor", Sensor]
        ].
        each do |elt_xpath, elt_class|
          network_xml.xpath(elt_xpath).each do |elt_xml|
            elt_class.create_from_xml(elt_xml, ctx, self)
          end
        end
      end

      ## DirectionsCache
      ## IntersectionCache
    end
  end
end
