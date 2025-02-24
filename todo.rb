# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'erubi'

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
    'The list name must contain valid alphanumeric characters'
  elsif invalid_length?(name)
    'The list name must be between 1 and 100 characters'
  end
end

def remove_white_spaces(list_name)
  list_name.strip
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
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end
