source :rubygems

#------------------------------
# for server and worker installations
#
mri_19_gems = %w{
  eventmachine
  sinatra
  sequel
  thin
  sqlite3-ruby
  rake
  nokogiri
  json
  pg
  sequel_pg
  rest-client
  haml
  fsdb
  aws-s3
}

mri_19_gems.each do |g|
  gem g, :platforms => :mri_19
end
gem 'sinatra-jsonp', :require => 'sinatra/jsonp', :platforms => :mri_18

#------------------------------
# for worker installations
#
jruby_gems = %w{
  jruby-openssl
  rest-client
  mime-types
  nokogiri
  aws-s3
}

jruby_gems.each do |g|
  gem g, :platforms => :jruby
end
