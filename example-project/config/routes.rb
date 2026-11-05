Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  get '/send_logs', to: 'example#send_logs', as: 'send_logs'
  get '/raise_error', to: 'example#raise_error', as: 'raise_error'

  # Defines the root path route ("/")
  root 'example#index'  
end
