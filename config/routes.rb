Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "rails/health#show"
  
  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication (Devise with custom controllers)
      devise_for :users, path: 'auth', controllers: {
        registrations: 'api/v1/auth/registrations',
        sessions: 'api/v1/auth/sessions'
      }, skip: [:passwords, :confirmations, :unlocks]
      
      # Override Devise routes to use POST for sign_up and sign_in
      devise_scope :user do
        post 'auth/sign_up', to: 'auth/registrations#create'
        post 'auth/sign_in', to: 'auth/sessions#create'
        delete 'auth/sign_out', to: 'auth/sessions#destroy'
        
        # Account linking
        post 'auth/link_wallet', to: 'auth/account_linking#link_wallet'
        post 'auth/link_email', to: 'auth/account_linking#link_email'
        get 'auth/me', to: 'auth/account_linking#me'
        
        # Password management
        post 'auth/change_password', to: 'auth/passwords#change_password'
      end
      
      # Artists
      resources :artists, only: [:index, :show, :update] do
        member do
          get :profile
          get :albums
          get :tokens
          get :events
          get :livestreams
        end
      end
      
      # Artist Dashboard (current user's artist data)
      namespace :artist do
        get 'dashboard', to: 'dashboard#index'
        
        # Shop Management
        resources :orders, only: [:index, :show] do
          member do
            patch :update_status
            post :add_note
          end
          collection do
            get :export
          end
        end
        
        resource :inventory, only: [] do
          collection do
            get :index
          end
          member do
            patch ':id/adjust', to: 'inventory#adjust_stock'
            patch ':id/variant/:variant_id/adjust', to: 'inventory#adjust_variant_stock'
          end
        end
        
        resource :shop_analytics, only: [] do
          collection do
            get :index
            get :export
          end
        end
      end
      
      # Follow/Unfollow artists
      post 'artists/:id/follow', to: 'follows#create'
      delete 'artists/:id/follow', to: 'follows#destroy'
      get 'artists/:id/followers', to: 'follows#followers'
      get 'users/:id/following', to: 'follows#following'
      
      # Artist Tokens (Bonding Curve & DEX)
      resources :artist_tokens, path: 'tokens', only: [:index, :show, :create] do
        member do
          get :trades
          post :buy
          post :sell
          get :chart
        end
      end
      
      # DEX
      namespace :dex do
        post 'swap'
        get 'pools'
        get 'pools/:id', to: 'pools#show'
        post 'pools/:id/add_liquidity', to: 'pools#add_liquidity'
        post 'pools/:id/remove_liquidity', to: 'pools#remove_liquidity'
      end
      
      # Music
      resources :albums, only: [:index, :show, :create, :update] do
        resources :tracks, only: [:index, :show, :create, :update]
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'Album' }
        member do
          patch :bulk_update_track_access
          post :like, to: 'likes#create', defaults: { likeable_type: 'Album' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Album' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'Album' }
        end
      end
      
      resources :tracks, only: [:index, :show] do
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'Track' }
        member do
          get :stream
          post :log_stream
          post :purchase
          patch :update_access
          post :like, to: 'likes#create', defaults: { likeable_type: 'Track' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Track' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'Track' }
        end
      end
      
      # Videos
      resources :videos do
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'Video' }
        member do
          get :watch
          post :log_view
          post :purchase
          post :publish
          post :like, to: 'likes#create', defaults: { likeable_type: 'Video' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Video' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'Video' }
        end
      end
      
      # Minis (short-form content)
      resources :minis do
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'Mini' }
        collection do
          get :feed
          get :trending
          get :following
        end
        member do
          get :watch
          post :log_view
          post :purchase
          post :publish
          post :share
          post :like, to: 'likes#create', defaults: { likeable_type: 'Mini' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Mini' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'Mini' }
        end
      end
      
      # Playlists
      resources :playlists do
        member do
          post 'add_track/:track_id', to: 'playlists#add_track'
          delete 'remove_track/:track_id', to: 'playlists#remove_track'
        end
      end
      
      # Events & Tickets
      resources :events do
        resources :ticket_tiers, only: [:index, :create, :update]
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'Event' }
        member do
          post :purchase_ticket
          post :like, to: 'likes#create', defaults: { likeable_type: 'Event' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Event' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'Event' }
        end
      end
      
      resources :tickets, only: [:index, :show] do
        member do
          post :checkin
          get :qr_code
        end
      end
      
      # Livestreams
      resources :livestreams do
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'Livestream' }
        member do
          post :start
          post :stop
          post :tip
          get :messages
          get :status
          post :like, to: 'likes#create', defaults: { likeable_type: 'Livestream' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Livestream' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'Livestream' }
        end
        resources :messages, only: [:create], controller: 'livestream_messages'
      end
      
      # RTMP Streaming webhooks
      post 'streaming/validate', to: 'streaming#validate'
      post 'streaming/stream_started', to: 'streaming#stream_started'
      post 'streaming/stream_ended', to: 'streaming#stream_ended'
      
      # Notifications
      resources :notifications, only: [:index, :destroy] do
        collection do
          post :mark_all_as_read
        end
        member do
          post :mark_as_read
        end
      end
      
      # Commerce
      # Shop & Merchandise
      resources :categories, only: [:index, :show]
      resources :merch_items, path: 'merch' do
        collection do
          get :recently_viewed
        end
        member do
          get :quick_view
        end
      end
      
      # Reviews
      resources :reviews do
        member do
          post :vote
          post :respond
        end
      end
      
      # Wishlists
      resources :wishlists do
        member do
          post 'items', to: 'wishlists#add_item'
          delete 'items/:item_id', to: 'wishlists#remove_item'
        end
      end
      
      # Direct Messaging
      resources :conversations do
        member do
          patch :archive
          patch :mute
          post :mark_read
        end
        resources :messages, only: [:create]
      end
      
      resources :messages, only: [] do
        member do
          patch :mark_read, to: 'messages#mark_read'
        end
      end
      
      # Orders
      resources :orders, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end
      
      resources :fan_passes, only: [:index, :show, :create, :update, :destroy] do
        resources :comments, only: [:index, :create], defaults: { commentable_type: 'FanPass' }
        member do
          post :purchase
          get :holders
          get :dividends_history, path: 'dividends'
          post :distribute_dividends
          post :like, to: 'likes#create', defaults: { likeable_type: 'FanPass' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'FanPass' }
          get :likes, to: 'likes#index', defaults: { likeable_type: 'FanPass' }
        end
      end
      
      # Comments (for update/delete and likes)
      resources :comments, only: [:update, :destroy] do
        member do
          post :like, to: 'likes#create', defaults: { likeable_type: 'Comment' }
          delete :like, to: 'likes#destroy', defaults: { likeable_type: 'Comment' }
        end
      end
      
      # Airdrops
      resources :airdrops, only: [:index, :show, :create] do
        member do
          get 'proof/:wallet_address', to: 'airdrops#proof'
          post :claim
        end
      end
      
      # Social
      resources :follows, only: [:create, :destroy]
      
      # Reports & Moderation
      resources :reports, only: [:create, :index, :show, :update]
      
      # User profile
      get 'profile', to: 'users#profile'
      patch 'profile', to: 'users#update_profile'
      get 'profile/streams', to: 'users#streams'
      get 'profile/purchases', to: 'users#purchases'
      get 'profile/tickets', to: 'users#tickets'
      
      # User settings
      get 'users/notification_preferences', to: 'users#notification_preferences'
      patch 'users/notification_preferences', to: 'users#update_notification_preferences'
      delete 'users/account', to: 'users#destroy_account'
      
      # Platform
      get 'platform/metrics', to: 'platform#metrics'
      get 'platform/token', to: 'platform#token_info'
      
      # Admin routes (not using namespace since controller is AdminController, not Admin::DashboardController)
      get 'admin/dashboard', to: 'admin#dashboard'
      get 'admin/users', to: 'admin#users'
      patch 'admin/users/:id', to: 'admin#update_user'
      get 'admin/analytics', to: 'admin#analytics'
      get 'admin/content', to: 'admin#content'
      post 'admin/content/:type/:id/feature', to: 'admin#feature_content'
      delete 'admin/content/:type/:id/remove', to: 'admin#remove_content'
      get 'admin/revenue', to: 'admin#revenue'
      post 'admin/verification/:id/approve', to: 'admin#approve_verification'
      post 'admin/verification/:id/reject', to: 'admin#reject_verification'
      
      # Search
      get 'search', to: 'search#index'
    end
  end
  
  # ActionCable WebSocket
  mount ActionCable.server => '/cable'
end
