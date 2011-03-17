# Example of using the runweb api to upload to s3.

RUNWEB_PORT = Integer(ENV["RUNWEB_PORT"]) || 9097
RUNWEB_HOST = ENV["RUNWEB_HOST"] || 'localhost'

require 'rest-client'

expiry = 60 # seconds
ext = "xml"

url = "http://#{RUNWEB_HOST}:#{RUNWEB_PORT}/store?expiry=#{expiry}&ext=#{ext}"
data = "<foo>bar</foo>"

$stderr.puts "posting to #{url}"

res = RestClient.post url, data, :content_type => :xml
puts res
