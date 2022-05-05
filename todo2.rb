require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_class(list)
    "complete" if list_completed?(list)
  end

  def list_completed?(list)
    todos = list[:todos]

    sufficient_qty = todos.size >= 1
    all_completed = todos.all? { |todo| todo[:completed] }

    sufficient_qty && all_completed
  end

  def completed_over_total(id)
    list = session[:lists][id]
    todos = list[:todos]

    completed = todos.count { |todo| todo[:completed] }
    total = todos.size

    "#{completed} / #{total} "
  end

  def sort_lists(lists, &block)
    complete, incomplete = lists.partition do |list|
      list_completed?(list)
    end

    [incomplete, complete].each do |list_cat|
      list_cat.each { |list| yield list, lists.index(list)}
    end
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }

    [incomplete, complete].each do |todo_cat|
      todo_cat.each { |todo| yield todo }
    end
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

def load_list(index)
  index = index.to_i
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = 'That list does not exist.'
  redirect '/lists'
end

# view list of all lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'Please enter a name between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# edit the name of an existing list
post '/lists/:id' do |id|
  id = id.to_i
  list_name = params[:list_name].strip
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# view a single todo list
get '/lists/:id' do |id|
  @list_id = id.to_i
  @list = load_list(id)
  @todos = @list[:todos]

  is_completed = params[:completed] == "true"
  @status = is_completed ? "complete" : ""
  erb :list, layout: :layout
end

# render the new todo form
get '/lists/:id/new' do |id|
  @id = id
  erb :new_todo, layout: :layout
end

# render the edit todo name form
get '/lists/:id/edit' do |id|
  @id = id
  @list = load_list(id)

  erb :edit_list, layout: :layout
end

# delete a list
delete '/lists/:id/delete' do |id|
  @id = id.to_i
  session[:lists].reject! { |list| list[:id] == @id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists'
  else
    session[:success] = "The list has been deleted."
    redirect '/lists'
  end
end

# delete a todo
post '/lists/:list_id/todos/:todo_id/delete' do |list_id, todo_id|
  @list_id = list_id.to_i
  todo_id = todo_id.to_i
  @list = load_list(@list_id)

  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

def next_id(items)
  max = items.map { |item| item[:id] }.max || 0
  max + 1
end

# create a new todo
post '/lists/:id/todos' do |id|
  @list_id = id.to_i
  @list = load_list(@list_id)
  @todos = @list[:todos]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_id(@todos)
    @todos << { id: id, name: text, completed: false }
    session[:success] = 'The task has been created.'
    redirect "/lists/#{@list_id}"
  end
end 

# Update the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = :is_completed
  
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Complete all todos
post '/lists/:list_id/complete_all' do |list_id|
  todos = session[:lists][list_id.to_i][:todos]
  todos.each do |todo|
    todo[:completed] = "true"
  end

  session[:success] = "All todos have been completed."
  redirect "lists/#{list_id}"
end

not_found do
  redirect '/lists'
end