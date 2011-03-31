require 'sequel'
require 'nokogiri'
require 'pp'
require 'logger'
require 'fileutils'

topdir = File.expand_path("../..")
libdir = File.join(topdir, "lib")
$LOAD_PATH.unshift libdir

datadir = File.join(topdir, 'var/data')
FileUtils.mkdir_p datadir
DB = Sequel.sqlite(File.join(datadir, 'test.db'))
#DB.loggers << Logger.new($stderr)

test_doc = File.join(topdir, "dbweb/doc/short.xml")

require 'db/schema'
require 'db/import/scenario'

module Aurora
  module Parser
    # +src+ can be io, string, etc.
    def parse src
      ## optionally validate
      Nokogiri.XML(src).xpath("/AuroraRNM")[0]
    end
  end
  extend Parser
  
  class Importer
    include Parser
    
    attr_reader :src
    attr_reader :scenario_xml
    attr_reader :scenario
    
    def initialize src, opts = {}
      @src = src
      @opts = opts
    end
    
    # +src+ can be io, string, etc.
    def import
      @network_id_map = {}
      @node_id_map = {}
      @link_id_map = {}
      @scenario_xml = parse(src)
      
      DB.transaction do
        @scenario = Scenario.import_xml(scenario_xml)
      end
      
      #pp @node_id_map
      #pp @link_id_map
      
      ##return scenario[:id]
    end
    
#    # Note: Scenario object == AuroraRNM element
#    def import_scenario
#      @scenario = rnm
#      Scenario.create(
#        ### name
#        ### description
#        ### dt == display / tp ?
#        ### b_time == display / timeInitial ?
#        ### e_time
#        ### length_units
#        ### v_types set or string?
#        # network_id
#        # demand_profile_group_id
#        # capacity_profile_group_id
#        # split_ratio_profile_group_id
#      )
#    end
#    
#    def import_networks
#      rnm.xpath("//network").each do |network_elt|
#        desc = node_elt.xpath('description')[0]
#        network = Network.create(
#          :description  => desc && desc.content,
#          ### are these right?
#          :dt           => tp
#          :ml_control   => 
#          :q_control    => 
#        )
#        @network_id_map[network_elt["id"]] = network.id
#      
#        if scenario and ###this is the top level network
#          scenario.network_id = network.id
#        end
#      end
#    end
#    
#    def import_nodes
#      rnm.xpath("//node").each do |node_elt|
#        point = node_elt.xpath('position/point')[0]
#        desc = node_elt.xpath('description')[0]
#        ### inputs, outputs, splitratios, etc?
#        node = Node.create(
#          :name => node_elt["name"],
#          :description => desc && desc.content,
#          :type_node => node_elt["type"],
#          :geo_x => point["x"],
#          :geo_y => point["y"],
#          :geo_z => point["z"]
#        )
#        @node_id_map[node_elt["id"]] = node.id
#        
#        ### network_nodes
#      end
#    end
#    
#    def import_links
#      rnm.xpath("//link").each do |link_elt|
#        link = Link.create(
#          :name       => link_elt["name"],
#          :type_link  => link_elt["type"],
#          :length     => link_elt["length"],
#          :lanes      => link_elt["lanes"]###,
#          ###capacity
#          ###v
#          ###w
#          ###jam_den
#          ###cap_drop
#          ###geo_cache
#        )
#        @link_id_map[link_elt["id"]] = link.id
#
#        ### network_links
#      end
#    end
  end
  
  def self.import src
    Importer.new(src).import
  end
end

Aurora.import(File.read(test_doc))

#pp DB[:scenarios].all
#pp DB[:networks].all
#pp DB[:vehicle_types].all
#pp DB[:nodes].all

pp Aurora::Scenario[:id=>1]
pp Aurora::Scenario[:id=>1].network
pp Aurora::Scenario[:id=>1].vehicle_types
pp Aurora::Scenario[:id=>1].network.nodes
pp Aurora::Scenario[:id=>1].network.links

### how to make this work?
###pp Aurora::Scenario[:id=>1].network.nodes[:id => 1].split_ratio_profiles

#pp Aurora::Node[:id => 1].split_ratio_profiles
puts
pp Aurora::Node[:id => 3].outputs
