# config/routes.rb
Rails.application.routes.draw do
  get "up", to: "health#show"

  resources :providers, only: [] do
    resources :availabilities, only: :index, module: :providers
  end

  resources :appointments, only: %i[create destroy]
end
