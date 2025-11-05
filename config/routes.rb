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
          get :albums
          get :tokens
          get :events
          get :livestreams
        end
      end
      
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
        member do
          patch :bulk_update_track_access
        end
      end
      
      resources :tracks, only: [:index, :show] do
        member do
          get :stream
          post :log_stream
          post :purchase
          patch :update_access
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
        member do
          post :purchase_ticket
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
        member do
          post :start
          post :stop
          post :tip
          get :messages
          get :status
        end
        resources :messages, only: [:create], controller: 'livestream_messages'
      end
      
      # RTMP Streaming webhooks
      post 'streaming/validate', to: 'streaming#validate'
      post 'streaming/stream_started', to: 'streaming#stream_started'
      post 'streaming/stream_ended', to: 'streaming#stream_ended'
      
      # Commerce
      resources :merch_items, path: 'merch'
      resources :orders, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end
      
      resources :fan_passes, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :purchase
          get :holders
          get :dividends_history, path: 'dividends'
          post :distribute_dividends
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
