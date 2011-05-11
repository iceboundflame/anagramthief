Anathief::Application.routes.draw do
  root :to => 'welcome#index'

  match '/auth/fb_callback', :to => 'sessions#fb_callback', :as => 'sessions_fb_callback'
  match '/auth/guest', :to => 'sessions#guest_in', :as => 'sessions_guest_in'
  match '/auth/logout', :to => 'sessions#logout', :as => 'sessions_logout'

  match '/games/list', :to => 'games#list', :as => 'games_list'
  match '/games/create', :to => 'games#create', :as => 'games_create'

  match '/play/:id', :to => 'play#play', :as => 'play'
  match '/play/:id/chat', :to => 'play#chat', :as => 'play_chat'
  match '/play/:id/flip_char', :to => 'play#flip_char', :as => 'play_flip_char'
  match '/play/:id/claim', :to => 'play#claim', :as => 'play_claim'
  match '/play/:id/vote_done', :to => 'play#vote_done', :as => 'play_vote_done'
  match '/play/:id/restart', :to => 'play#restart', :as => 'play_restart'
  match '/play/:id/heartbeat', :to => 'play#heartbeat', :as => 'play_heartbeat'
  match '/play/:id/refresh', :to => 'play#refresh', :as => 'play_refresh'

  match '/play/:id/invite_form', :to => 'play#invite_form', :as => 'play_invite_form'

  #resources :games, :module => 'admin', :path => '/admin/games'
  #namespace 'admin' do
    #resources :games
  #end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
