require 'sequel'
require 'nokogiri'
require 'pp'
require 'logger'
require 'fileutils'

topdir = File.expand_path("../..")
libdir = File.join(topdir, "lib")
$LOAD_PATH.unshift libdir

if ENV["SQLITEFILE"] ##
  datadir = File.join(topdir, 'var/data')
  FileUtils.mkdir_p datadir
  db_filename = File.join(datadir, 'test.db')
  FileUtils.rm_f db_filename
  DB = Sequel.sqlite(db_filename)
else
  DB = Sequel.sqlite
end

if ENV["LOGTEST"] ##?
  DB.loggers << Logger.new($stderr)
end

if ENV["INPUTTEST"] ##?
  test_doc = ENV["INPUTTEST"]
else
  test_doc = File.join(topdir, "dbweb/doc/short.xml")
end

# create tables if they don't exist
require 'db/schema'

require 'db/model/aurora'
require 'db/import/scenario'

module Aurora
  module Parser
    # +src+ can be io, string, etc.
    def parse src
      ## optionally validate
      Nokogiri.XML(src).xpath("/scenario")[0]
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
    # Returns the ID of the imported scenario.
    def import
      @scenario_xml = parse(src)
      
      DB.transaction do
        @scenario = Scenario.create_from_xml(scenario_xml)
      end
      
      return scenario[:id]
    end
    
  end
  
  def self.import src
    Importer.new(src).import
  end
end

Aurora.import(File.read(test_doc))

#pp DB[:scenarios].all
#pp DB[:networks].all
#pp DB[:nodes].all
#pp DB[:links].all
#pp DB[:vehicle_types].all

#sc = Aurora::Scenario[1]
#pp sc
#pp sc.vehicle_types
#
#nw = Aurora::Scenario[1].network
#pp nw
#pp nw.nodes
#pp nw.links

#puts
#rt = Aurora::Route.first
#pp rt
#pp rt.links

#puts
#nw.nodes.each do |node|
#  if node.inputs.size > 0
#    pp [node, node.inputs]
#  end
#end

#pp Aurora::Sensor.first

sc = Aurora::Scenario.first
pp sc
pp sc.srp_set
pp sc.srp_set.srps
