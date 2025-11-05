Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "rails/health#show"
  
  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      namespace :auth do
        post 'sign_up', to: 'registrations#create'
        post 'sign_in', to: 'sessions#create'
        delete 'sign_out', to: 'sessions#destroy'
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
      resources :merch_items, path: 'merch'
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
      
      # Platform
      get 'platform/metrics', to: 'platform#metrics'
      get 'platform/token', to: 'platform#token_info'
      
      # Search
      get 'search', to: 'search#index'
    end
  end
  
  # ActionCable WebSocket
  mount ActionCable.server => '/cable'
end
