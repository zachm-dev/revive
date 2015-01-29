require 'sidekiq/pro/web'

Rails.application.routes.draw do

  #root 'dashboard#index'
  root 'home#index'
  get 'home', to: 'home#index', as: 'home'
  #root 'sessions#new'
  get 'signup', to: 'users#new', as: 'signup'
  get 'login', to: 'sessions#new', as: 'login'
  get 'logout', to: 'sessions#destroy', as: 'logout'
  resources :users
  resources :sessions
  resources :dashboard
  get 'projects/' => "crawls#index", as: :projects
  get 'projects/new' => "crawls#new", as: :new_project
  get 'projects/:id' => "crawls#show", as: :crawl_path
  resources :crawls
  get 'domains/:id' => "sites#index", as: :domains
  get 'sites/:id/urls' => "sites#all_urls", as: :all_urls
  get 'sites/:id/internal' => "sites#internal", as: :internal
  get 'sites/:id/external' => "sites#external", as: :external
  get 'sites/:id/broken' => "sites#broken", as: :broken
  get 'sites/:id/available' => "sites#available", as: :available
  resources :sites
  resources :pages
  post 'api_create', to: 'crawls#api_create'
  get 'checkout', to: 'checkout#index', as: :checkout
  resources :checkout
  
  mount Sidekiq::Web, at: '/sidekiq'
  mount Sidekiq::Monitor::Engine => '/sidekiq_monitor'
  #mount PgHero::Engine, at: "pghero"
  
  get '*path' => redirect('/dashboard')

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
