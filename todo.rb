require "sinatra"
require "sinatra/reloader" if development?
require "erubi"

get "/" do
  erb "You have no lists.", layout: :layout
end
