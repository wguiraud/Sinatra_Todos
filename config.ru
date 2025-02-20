require_relative './todo'

use Rack::Session::Cookie, {
  secret: ENV['SESSION_SECRET'],
  key: 'rack.session',
  path: '/',
  #expire_after: 14400 # Session expiration time in seconds (optional)
}

run Sinatra::Application
