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
db_filename = File.join(datadir, 'test.db')
unless File.exist?(db_filename)
  abort "Database does not exist; rake test:import first."
end

DB = Sequel.sqlite(db_filename)
#DB.loggers << Logger.new($stderr)

require 'db/schema'
require 'db/export/scenario'

module Aurora
  class Exporter
    include Parser
  end
  
  def self.export src
    Exporter.new(src).import
  end
end

Aurora.export()

