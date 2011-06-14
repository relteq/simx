source :rubygems

#------------------------------
# for server and worker installations
#
mri_18_gems = %w{
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
}

mri_18_gems.each do |g|
  gem g, :platforms => :mri_18
end
gem 'async_sinatra', '~>0.5', :platforms => :mri_18
gem 'sinatra-jsonp', :require => 'sinatra/jsonp', :platforms => :mri_18

#------------------------------
# for worker installations
#
jruby_gems = %w{
  jruby-openssl
  rest-client
  mime-types
}

jruby_gems.each do |g|
  gem g, :platforms => :jruby
end
