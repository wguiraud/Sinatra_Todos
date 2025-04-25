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
  list = session[:lists].find { |l| l[:id] == list_id }
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

def next_element_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

helpers do
  def all_completed?(list)
    list[:todos].size.positive? && number_of_remaining_todos(list).zero?
  end

  def at_least_one_todo?(list)
    list[:todos].size.positive?
  end

  def number_of_remaining_todos(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def list_class(list)
    return unless all_completed?(list) && at_least_one_todo?(list)

    'complete'
  end

  def sort_lists(lists, &block)
    completed_lists, uncompleted_lists = lists.partition { |list| all_completed?(list) }

    uncompleted_lists.each(&block)
    completed_lists.each(&block)
  end

  def sort_todos(todos, &block)
    completed_todos, uncompleted_todos = todos.partition { |todo| todo[:completed] }

    uncompleted_todos.each(&block)
    completed_todos.each(&block)
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

# create a new list
post '/lists' do
  list_name = remove_white_spaces(params[:list_name])

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list '#{list_name}' has been created."
    redirect '/lists'
  end
end

# view a list
get '/lists/:id' do
  id = params[:id].to_i
  list = load_list(id)
  list_id = list[:id]
  list_name = list[:name]
  todos = list[:todos]
  todo_name = nil

  erb :list, locals: { list: list, list_name: list_name, list_id: list_id, todos: todos, todo_name: todo_name }
end

# edit a list
get '/lists/:id/edit' do
  id = params[:id].to_i
  list = load_list(id)
  list_id = list[:id]
  list_name = list[:name]

  erb :edit_list, locals: { list_id: list_id, list_name: list_name }
end

# update the name of an existing list list
post '/lists/:id' do
  id = params[:id].to_i
  list = load_list(id)
  list_id = list[:id]
  list_name = params[:list_name]

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, locals: { list_id: list_id, list_name: list_name }
  else
    list[:name] = list_name
    session[:success] = "The list's name has been updated to #{list_name}"
    redirect "/lists/#{list[:id]}"
  end
end

# delete a list
post '/lists/:id/delete' do
  id = params[:id].to_i
  list = load_list(id)
  list_id = list[:id]
  list_name = list[:name]

  session[:lists].reject! { |l| l[:id] == list_id }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = "The list '#{list_name}' was deleted."
    redirect '/lists'
  end
end

# add a todo to a list
post '/lists/:id/add_todo' do
  id = params[:id].to_i
  list = load_list(id)
  list_id = list[:id]
  list_name = list[:name]
  todo_name = remove_white_spaces(params[:todo_name])
  todos = list[:todos]

  error = error_for_todo_name(list, todo_name)

  if error
    session[:error] = error
    erb :list, locals: { list: list, list_id: list_id, list_name: list_name, todos: todos, todo_name: todo_name }
  else
    todo_id = next_element_id(todos)
    todos << { id: todo_id, name: todo_name, completed: false }
    session[:success] = "The todo '#{todo_name}' has been created successfully."
    redirect "/lists/#{list[:id]}"
  end
end

# delete a todo from the list
post '/lists/:id/todo/:todo_id/delete' do
  id = params[:id].to_i
  list = load_list(id)
  todo_id = params[:todo_id].to_i
  todo = list[:todos].find { |td| td[:id] == todo_id }
  todo_name = todo[:name]

  list[:todos].reject! { |td| td[:id] == todo_id }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = "The todo '#{todo_name}' was successfully deleted"
    redirect "/lists/#{list[:id]}"
  end
end

# mark a todo as completed
post '/lists/:id/todo/:todo_id' do
  id = params[:id].to_i
  list = load_list(id)
  todo_id = params[:todo_id].to_i

  is_completed = params[:completed] == 'true'
  todo = list[:todos].find { |td| td[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = 'The todo has been updated'
  redirect "/lists/#{list[:id]}"
end

# mark all todos as completed
post '/lists/:id/complete_all' do
  id = params[:id].to_i
  list = load_list(id)
  complete_all_todos(list)

  session[:success] = 'All the todos are completed'
  redirect "/lists/#{list[:id]}"
end
