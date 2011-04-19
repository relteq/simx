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
            raise "xml specified nonexistent network_id: #{network.id}" ##
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
      self.name         = network_xml["name"]

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

      network_xml.xpath("NodeList/node").each do |node_xml|
        ctx.defer do
          Node.create_from_xml(node_xml, ctx, self)
        end
      end

      network_xml.xpath("LinkList/link").each do |link_xml|
        ctx.defer do
          Link.create_from_xml(link_xml, ctx, self)
        end
      end
      
      network_xml.xpath("NetworkList/network").each do |subnetwork_xml|
        ctx.defer do
          Network.create_from_xml(subnetwork_xml, ctx, self)
        end
      end

      network_xml.xpath("ODList/od/PathList/path").each do |route_xml|
        ctx.defer do
          Route.create_from_xml(route_xml, ctx, self)
        end
      end
      
      network_xml.xpath("SensorList/sensor").each do |sensor_xml|
        ctx.defer do
          Sensor.create_from_xml(sensor_xml, ctx, self)
        end
      end

      ## DirectionsCache
      ## IntersectionCache
    end
  end
end
