Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  namespace :api do
    namespace :v1 do
      
      resources :users do 
        get :unassigned_artists, on: :collection
      end
      resources :artists do
        collection do
          get :all
          get :my_artists
          post :csv_import
          get :csv_export
        end
        member do 
          patch :assign_manager
          get :public_show
        end
      end
      resources :albums do
        collection do
          get :all
        end
      end
      resources :musics do
        collection do
          get :all
        end
      end
      resources  :genres

      get "/test", to: "test#index"
      post "/login", to: "auth#login"
      delete "/logout", to: "auth#logout"
      get "/profile", to: "auth#profile"
      patch "/update_profile", to: "auth#update_profile"

      post "register", to: "auth#register"
      post "refresh", to: "auth#refresh"

    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
