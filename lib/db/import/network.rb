require 'set'

require 'db/import/node'
require 'db/import/link'
require 'db/import/route'
require 'db/import/sensor'

module Aurora
  class Network
    include Aurora
    
    def self.create_from_xml network_xml, ctx, parent = nil
      members_before = nil
      
      id = import_id(network_xml["id"])
      nw = id && Network[id]
      if nw
        members_before = nw.select_members
      end

      network = create_with_id network_xml["id"] do |nw|
        ctx.defer do
          if parent
            nw.add_parent parent
            parent.add_child nw
          end
        end
        
        nw.import_xml network_xml, ctx, parent
      end
      
      if members_before
        ### shouldn't this be deferred?
        members_after = network.select_members
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

      network_xml.xpath("DirectionsCache").each do |dir_cache_xml|
        self.directions_cache = dir_cache_xml
      end

      network_xml.xpath("IntersectionCache").each do |int_cache_xml|
        self.intersection_cache = int_cache_xml
      end
    end

    # returns [ [:nodes, <set of node ids>], [:links, ...], ... ]
    def select_members
      [:networks, :links, :nodes, :routes, :sensors].map do |table|
        [table, Set.new(send(table).map{|m| m.id})]
      end
    end
  end
end
