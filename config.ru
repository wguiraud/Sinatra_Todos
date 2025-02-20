require_relative './todo'

#use Rack::Session::Cookie, {
#  secret: ENV['SESSION_SECRET'],
#  key: 'rack.session',
#  path: '/',
#  same_site: :lax  # or :strict, :none depending on your needs
#  #expire_after: 14400 # Session expiration time in seconds (optional)
#}

run Sinatra::Application
