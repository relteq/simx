require 'db/import/node'
require 'db/import/link'

module Aurora
  class Network
    include Aurora
    
    def self.create_from_xml network_xml, ctx, parent = nil
      create_with_id network_xml["id"] do |nw|
        if not nw.id
          nf = nw.network_family = NetworkFamily.create
          ctx.network_family_id_for_xml_id[network_xml["id"]] = nf.id
        end
        
        scenario = ctx.scenario

        if parent
          nw.tln = scenario.tln

        else # this network "is" a tln
          network_id = import_id(network_xml["network_id"])

          if network_id
            tln = Tln[network_id]
            if not tln
              raise "xml specified nonexistent network_id: #{network_id}" ##
            end
            nw.tln = tln
          
          else
            tln = nw.tln = Tln.create
            ctx.tln_id_for_xml_id[network_xml["network_id"]] = tln.id
          end
          
          if scenario.tln and scenario.tln != nw.tln
            raise "wrong tln"
          end
        end

        nw.import_xml network_xml, ctx, parent
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
#        node = Node.create_from_xml(node_xml, ctx)
#        add_node node
      end

      network_xml.xpath("NetworkList/network").each do |subnetwork_xml|
#        subnetwork = Network.create_from_xml(subnetwork_xml, ctx, self)
#        add_children subnetwork
      end

      network_xml.xpath("LinkList/link").each do |link_xml|
#        link = Link.create_from_xml(link_xml, ctx)
#        add_link link
      end
      
      network_xml.xpath("ODList/od/PathList/path").each do |path_xml|
        ### create route
      end
      
      network_xml.xpath("SensorList/sensor").each do |sensor_xml|
        ### create sensor
      end

      ## DirectionsCache
      ## IntersectionCache
    end
  end
end
