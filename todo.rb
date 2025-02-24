require "sinatra"
require "sinatra/reloader" if development?
require "erubi"

configure do
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  #set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

def used_name?(name)
  session[:lists].any? { |list| list[:name] == name }
end

def invalid_list_name?(list_name)
  valid_name = /^[a-zA-Z0-9_]+ ?[a-zA-Z0-9_]+$/
  !(list_name.match?(valid_name) && (1..100).include?(list_name.length))
end

def remove_white_spaces(list_name)
  list_name.strip
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  lists = session[:lists]

  erb :lists, locals: { lists: lists }
end

get "/lists/new" do
  erb :new_list
end

post "/lists" do
  list_name = remove_white_spaces(params[:list_name])

  if invalid_list_name?(list_name)
    session[:error] = "The list name must be between 1 and 100 characters"
    erb :new_list
  elsif used_name?(list_name)
    session[:error] = "The list name must be unique"
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end

end
