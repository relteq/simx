require 'set'

require 'db/import/node'
require 'db/import/link'
require 'db/import/route'
require 'db/import/sensor'

module Aurora
  class Tln
    include Aurora

    # returns [ ["nodes", <set of node ids>], ["links", ...], ... ]
    def select_members
      [:networks, :links, :nodes, :routes, :sensors].map do |table|
        [table, Set.new(send(table).map{|m| m.id})]
      end
    end
  end
  
  class Network
    include Aurora
    
    def self.create_from_xml network_xml, ctx, parent = nil
      members_before = nil

      if parent
        tln = parent.tln
      
      else # this network "is" a tln
        network_id = import_id(network_xml["network_id"])
        if network_id
          tln = Tln[network_id]
          if tln
            members_before = tln.select_members
          else
            tln = Tln.create do |tln|
              tln.id = network_id
            end
          end
        
        else
          tln = Tln.create
          ctx.tln_id_for_xml_id[network_xml["network_id"]] = tln.id
        end
      end

      network = create_with_id network_xml["id"], tln.id do |network|
        if network.id
          NetworkFamily[network.id] or
            NetworkFamily.create {|nf| nf.id = network.id}
        else
          nf = network.network_family = NetworkFamily.create
          ctx.network_family_id_for_xml_id[network_xml["id"]] = nf.id
        end
        
        network.tln = tln
        network.parent = parent if parent
        network.import_xml network_xml, ctx, parent
      end
      
      if members_before
        members_after = tln.select_members
        members_before.zip(members_after).each do |(table, set0), (_, set1)|
          DB[table].where(:id => (set0 - set1).to_a).delete
        end
      end
      
      return network
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
