# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'erubi'
#require 'pry'

configure do
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  set :erb, escape_html: true
end

before do
  session[:lists] ||= []
end

def used_list_name?(name)
  session[:lists].any? { |list| list[:name] == name }
end

def used_todo_name?(list, name)
  list[:todos].any? { |todo| todo[:name] == name }
end


def invalid_character?(name)
  valid_characters = /^[a-zA-Z0-9_-]+ ?[a-zA-Z0-9_]+$/
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

def error_for_todo_name(list, name)
  if used_todo_name?(list, name)
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

def complete_all_todos(list)
  list[:todos].each { |todo| todo[:completed] = true }
end

def load_list(list_id)
  unless (0..session[:lists].size).include?(list_id)
    session[:error] = "The specified list was not found"
    redirect '/lists'
  end
end

helpers do
  def all_completed?(list)
    list[:todos].size > 0 && number_of_remaining_todos(list) == 0
  end

  def at_least_one_todo?(list)
    list[:todos].size > 0
  end

  def number_of_remaining_todos(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def list_class(list)
    if all_completed?(list) && at_least_one_todo?(list)
      "complete"
    end
  end

  def sort_lists(lists, &block)
    completed_lists, uncompleted_lists = lists.partition {|list| all_completed?(list)}

    uncompleted_lists.each { |list| yield(list, lists.index(list)) }
    completed_lists.each { |list| yield(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    completed_todos, uncompleted_todos = todos.partition { |todo| todo[:completed]}

    uncompleted_todos.each { |todo| yield(todo, todos.index(todo))}
    completed_todos.each { |todo| yield(todo, todos.index(todo))}
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
  load_list(list_id)

  list_name = session[:lists][list_id][:name]
  list = session[:lists][list_id]
  todos = session[:lists][list_id][:todos]
  todo_name = nil

  erb :list, locals: { list: list, list_name: list_name, list_id: list_id,
                       todos: todos, todo_name: todo_name}
end

get '/lists/:id/edit' do
  list_id = params[:id].to_i
  load_list(list_id)
  list_name = session[:lists][list_id][:name]

  erb :edit_list, locals: { list_id: list_id, list_name: list_name }
end

post '/lists/:id' do
  list_id = params[:id].to_i
  load_list(list_id)
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
  load_list(list_id)
  list_name = session[:lists][list_id][:name]
  session[:lists].delete_at(list_id)

  session[:success] = "The list '#{list_name}' was deleted."
  redirect "/lists"
end

post "/lists/:id/add_todo" do
  list_id = params[:id].to_i
  load_list(list_id)
  list_name = session[:lists][list_id][:name]
  todo_name = remove_white_spaces(params[:todo_name])
  todos = session[:lists][list_id][:todos]
  list = session[:lists][list_id]

  error = error_for_todo_name(list, todo_name)
  if error
    session[:error] = error
    erb :list, locals: { list: list, list_id: list_id, list_name: list_name,
                         todos: todos, todo_name: todo_name }
  else
    todos << { name: todo_name, completed: false }
    session[:success] = "The todo '#{ todo_name}' has been created successfully."
    redirect "/lists/#{list_id}"
  end

end

post "/lists/:id/todo/:todo_id/delete" do
  list_id = params[:id].to_i
  load_list(list_id)
  todo_id = params[:todo_id].to_i
  todo_name = session[:lists][list_id][:todos][todo_id][:name]

  session[:lists][list_id][:todos].delete_at(todo_id)
  session[:success] = "The todo '#{todo_name}' was successfully deleted"
  redirect "/lists/#{list_id}"
end

post "/lists/:id/todo/:todo_id" do
  list_id = params[:id].to_i
  load_list(list_id)
  todo_id = params[:todo_id].to_i
  list = session[:lists][list_id]

  if params[:completed] == 'false'
    list[:todos][todo_id][:completed] = false
    session[:success] = "The todo has been updated"
    redirect "/lists/#{list_id}"
  else
    list[:todos][todo_id][:completed] = true
    session[:success] = "The todo has been updated"
    redirect "/lists/#{list_id}"
  end
end

post "/lists/:id/complete_all" do
  list_id = params[:id].to_i
  load_list(list_id)
  list = session[:lists][list_id]
  complete_all_todos(list)

  session[:success] = 'All the todos are completed'
  redirect "/lists/#{list_id}"
end