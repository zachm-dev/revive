require 'sidekiq/pro/web'

Rails.application.routes.draw do

  # root 'home#index'
  root 'plans#index'
  get 'home', to: 'home#index', as: 'home'
  get :dashboard, to: 'dashboard#index'
  
  get 'terms', to: 'home#terms', as: 'terms'
  get 'earnings_disclaimer', to: 'home#earnings_disclaimer', as: 'earnings_disclaimer'
  get 'general_disclaimer', to: 'home#general_disclaimer', as: 'general_disclaimer'

  get 'domains/:id' => "sites#index", as: :domains
  
  get 'copy_to_clipboard' => 'application#copy_to_clipboard', as: :copy_to_clipboard
  
  resource :subscriptions
  get 'create_trial_for_existing_customer' => 'subscriptions#create_trial_for_existing_customer', as: :create_trial_for_existing_customer
  get 'reactivate' => 'subscriptions#reactivate', as: :reactivate
  
  resources :pages
  resources :plans

  # Users
  resources :users
  resources :sessions
  resources :password_resets
  get 'signup', to: 'users#new', as: 'signup'
  get 'login', to: 'sessions#new', as: 'login'
  get 'logout', to: 'sessions#destroy', as: 'logout'
  get :account, to: 'users#account'

  # Sites
  resources :sites do
    collection do
      put 'sites/:id/save_bookmarked' => "sites#save_bookmarked", as: :save_bookmarked
      put 'sites/:id/unbookmark' => "sites#unbookmark", as: :unbookmark
      get ':id/bookmarked' => "sites#bookmarked", as: :bookmarked
      get 'delete', as: :delete
    end
  end
  get 'sites/:id/urls' => "sites#all_urls", as: :all_urls
  get 'sites/:id/internal' => "sites#internal", as: :internal
  get 'sites/:id/external' => "sites#external", as: :external
  get 'sites/:id/broken' => "sites#broken", as: :broken
  get 'sites/:id/available' => "sites#available", as: :available

  # Crawls
  resources :crawls
  get 'projects/' => "crawls#index", as: :projects
  get 'running_crawls' => "crawls#running", as: :running_crawls
  get 'finished_crawls' => "crawls#finished", as: :finished_crawls
  get 'projects/new' => "crawls#new", as: :new_project
  get 'projects/:id' => "crawls#show", as: :crawl_path
  get 'stop_crawl/:id' => 'crawls#stop_crawl', as: :stop_crawl
  post 'shut_down_crawl' => 'crawls#shut_down_crawl', as: :shut_down_crawl
  get 'crawls/keyword/new' => 'crawls#new_keyword_crawl', as: :new_keyword_crawl
  post 'crawls/keyword/create' => 'crawls#create_keyword_crawl', as: :create_keyword_crawl
  get 'crawls/reverse/new' => 'crawls#new_reverse_crawl', as: :new_reverse_crawl
  post 'crawls/reverse/create' => 'crawls#create_reverse_crawl', as: :create_reverse_crawl
  post 'api_create', to: 'crawls#api_create'
  post 'fetch_new_crawl', to: 'crawls#fetch_new_crawl'
  post 'call_crawl', to: 'crawls#call_crawl'
  post 'migrate_db', to: 'crawls#migrate_db'
  post 'process_new_crawl', to: 'crawls#process_new_crawl'
  get 'start_crawl', to: 'crawls#start_crawl', as: :start_crawl
  get 'delete_crawl/:id', to: 'crawls#delete_crawl', as: :delete_crawl

  resources :pending_crawls do
    collection {post :sort}
  end

  # Admin
  resources :admins do
    collection do
      get :become_user
      get :edit_user
      put :update_user
    end
  end

  mount Sidekiq::Web, at: '/sidekiq'

  # get '*path' => redirect('/dashboard')

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
