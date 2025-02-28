# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'erubi'
require 'pry'

configure do
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
end

before do
  session[:lists] ||= []
end

def used_list_name?(name)
  session[:lists].any? { |list| list[:name] == name }
end

def used_todo_name?(name)
  session[:lists].select do |list|
    list[:todos].any? { |todo| todo[:name] == name }
  end.size > 0
end


def invalid_character?(name)
  valid_characters = /^[a-zA-Z0-9_]+ ?[a-zA-Z0-9_]+$/
  !name.match?(valid_characters)
end

def invalid_length?(name)
  !(1..100).include?(name.size)
end

# using name instead of list_name as a parameter name makes the method
# more
# generic. it can be reused in another context if needed
def error_for_list_name(name)
  if used_list_name?(name)
    'The list name must be unique'
  elsif invalid_character?(name)
    'The name must contain valid alphanumeric characters'
  elsif invalid_length?(name)
    'The name must be between 1 and 100 characters'
  end
end

def error_for_todo_name(name)
  if used_todo_name?(name)
    'The todo name must be unique'
  elsif invalid_character?(name)
    'The name must contain valid alphanumeric characters'
  elsif invalid_length?(name)
    'The name must be between 1 and 100 characters'
  end
end

def remove_white_spaces(name)
  name.strip
end

def complete_all_todos(list_id)
  session[:lists][list_id][:todos].each do |todo|
    todo[:completed] = true
  end
end

helpers do
  def all_completed?(list_id)
    session[:lists][list_id][:todos].all? { |todo| todo[:completed] }
  end

  def at_least_one_todo?(list_id)
    session[:lists][list_id][:todos].size > 0
  end

  def number_of_remaining_todos(list_id)
    session[:lists][list_id][:todos].count { |td| !td[:completed] }
  end

  def list_class(list_id)
    if all_completed?(list_id) && at_least_one_todo?(list_id)
      "complete"
  end
  end
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  lists = session[:lists]

  erb :lists, locals: { lists: lists }
end

get '/lists/new' do
  erb :new_list
end

post '/lists' do
  list_name = remove_white_spaces(params[:list_name])

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list '#{ list_name }' has been created."
    redirect '/lists'
  end
end

get '/lists/:id' do
  list_id = params[:id].to_i
  list_name = session[:lists][list_id][:name]
  todos = session[:lists][list_id][:todos]
  todo_name = nil

  erb :list, locals: { list_name: list_name, list_id: list_id, todos: todos, todo_name: todo_name}
end

get '/lists/:id/edit' do
  list_id = params[:id].to_i
  list_name = session[:lists][list_id][:name]

  erb :edit_list, locals: { list_id: list_id, list_name: list_name }
end

post '/lists/:id' do
  list_id = params[:id].to_i
  list_name = params[:list_name]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, locals: { list_id: list_id, list_name: list_name }
  else
    session[:lists][list_id][:name] = list_name
    session[:success] = "The list's name has been updated to #{list_name}"

    redirect "/lists/#{list_id}"
  end
end

post "/lists/:id/delete" do
  list_id = params[:id].to_i
  list_name = session[:lists][list_id][:name]
  session[:lists].delete_at(list_id)

  session[:success] = "The list '#{list_name}' was deleted."
  redirect "/lists"
end

post "/lists/:id/add_todo" do
  list_id = params[:id].to_i
  list_name = session[:lists][list_id][:name]
  todo_name = remove_white_spaces(params[:todo_name])
  todos = session[:lists][list_id][:todos]

  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :list, locals: { list_id: list_id, list_name: list_name, todos:
      todos, todo_name: todo_name }
  else
    todos << { name: todo_name, completed: false }
    session[:success] = "The todo '#{ todo_name}' has been created successfully."
    redirect "/lists/#{list_id}"
  end

end

post "/lists/:id/todo/:todo_id/delete" do
  list_id = params[:id].to_i
  todo_id = params[:todo_id].to_i
  todo_name = session[:lists][list_id][:todos][todo_id][:name]

  session[:lists][list_id][:todos].delete_at(todo_id)
  session[:success] = "The todo '#{todo_name}' was successfully deleted"
  redirect "/lists/#{list_id}"
end

post "/lists/:id/todo/:todo_id" do
  list_id = params[:id].to_i
  todo_id = params[:todo_id].to_i
  todo_name = session[:lists][list_id][:todos][todo_id][:name]

  if params[:completed] == 'false'
    session[:lists][list_id][:todos][todo_id][:completed] = false
    session[:success] = "The '#{todo_name}' todo is now uncompleted!'"
    redirect "/lists/#{list_id}"
  else
    session[:lists][list_id][:todos][todo_id][:completed] = true
    session[:success] = "The '#{todo_name}' todo is now completed"
    redirect "/lists/#{list_id}"
  end
end

post "/lists/:id/complete_all" do
  list_id = params[:id].to_i
  complete_all_todos(list_id)

  session[:success] = 'All the todos are completed'
  redirect "/lists/#{list_id}"
end