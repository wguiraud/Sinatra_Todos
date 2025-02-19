require "sinatra"
require "sinatra/reloader"
require "erubi"

get "/" do
  erb "You have no lists.", layout: :layout
end
