require 'sequel'
require 'pp'
require 'logger'
require 'fileutils'

topdir = File.expand_path("../..")
libdir = File.join(topdir, "lib")
$LOAD_PATH.unshift libdir

if ENV["SQLITEFILE"] ##
  datadir = File.join(topdir, 'var/data')
  FileUtils.mkdir_p datadir
  db_filename = File.join(datadir, 't.db')
  FileUtils.rm_f db_filename
  DB = Sequel.sqlite(db_filename)
else
  DB = Sequel.sqlite
end

if ENV["LOGTEST"] ##?
  DB.loggers << Logger.new($stderr)
end

# create tables if they don't exist
require 'db/schema'

require 'db/model/aurora'

pp DB.schema(:scenarios)
