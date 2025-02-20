require "sinatra"
require "sinatra/reloader" if development?
require "erubi"

configure do
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
end


get "/" do
  redirect "/lists"
end

get "/lists" do
  lists = session[:lists]

  erb :lists, locals: { lists: lists}
end
