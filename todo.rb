require "sinatra"
require "sinatra/reloader" if development?
require "erubi"

configure do
  enable :sessions
  #set :session_secret, ENV['SESSION_SECRET']
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  lists = session[:lists]

  erb :lists, locals: { lists: lists}
end

get "/lists/new" do
  erb :new_list
end

post "/lists" do
  session[:lists] << { name: params[:list_name], todos: [] }
  redirect "/lists"
end
