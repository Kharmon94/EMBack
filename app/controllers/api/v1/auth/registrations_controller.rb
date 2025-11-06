module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json
        skip_before_action :authenticate_user!, only: [:create], raise: false
        
        # POST /api/v1/auth/sign_up
        # Body (Email): { email: "...", password: "...", role: "fan|artist", artist_name: "..." }
        # Body (Wallet): { wallet_address: "...", signature: "...", message: "...", role: "fan|artist", artist_name: "..." }
        def create
          role = params[:role] || 'fan'
          
          # Determine auth method
          if params[:wallet_address].present?
            create_with_wallet(role)
          elsif params[:email].present?
            create_with_email(role)
          else
            render json: { error: 'Must provide either email/password or wallet credentials' }, status: :unprocessable_entity
          end
        end
        
        private
        
        def create_with_wallet(role)
          wallet_address = params[:wallet_address]
          signature = params[:signature]
          message = params[:message]
          
          unless wallet_address && signature && message
            return render json: { error: 'Missing wallet credentials' }, status: :unprocessable_entity
          end
          
          # TODO: Verify Solana signature (implement in SolanaService)
          
          # Check if wallet already exists
          if User.exists?(wallet_address: wallet_address)
            return render json: { error: 'Wallet address already registered' }, status: :unprocessable_entity
          end
          
          # Create user with wallet (no email required)
          user = User.new(
            wallet_address: wallet_address,
            role: role
          )
          
          if user.save
            create_artist_profile(user) if role == 'artist'
            sign_in(user)
            render json: {
              message: 'Account created successfully',
              user: user_json(user)
            }, status: :created
          else
            render json: { error: 'Failed to create account', details: user.errors }, status: :unprocessable_entity
          end
        end
        
        def create_with_email(role)
          email = params[:email]
          password = params[:password]
          
          unless email && password
            return render json: { error: 'Email and password required' }, status: :unprocessable_entity
          end
          
          # Check if email already exists
          if User.exists?(email: email)
            return render json: { error: 'Email already registered' }, status: :unprocessable_entity
          end
          
          # Create user with email/password (no wallet required)
          user = User.new(
            email: email,
            password: password,
            role: role
          )
          
          if user.save
            create_artist_profile(user) if role == 'artist'
            sign_in(user)
            render json: {
              message: 'Account created successfully',
              user: user_json(user)
            }, status: :created
          else
            render json: { error: 'Failed to create account', details: user.errors }, status: :unprocessable_entity
          end
        end
        
        def create_artist_profile(user)
          if params[:artist_name].present?
            user.create_artist!(
              name: params[:artist_name],
              bio: params[:artist_bio],
              verified: false
            )
          end
        end
        
        def user_json(user)
          {
            id: user.id,
            email: user.email,
            wallet_address: user.wallet_address,
            role: user.role,
            auth_methods: user.auth_methods,
            has_email_auth: user.has_email_auth?,
            has_wallet_auth: user.has_wallet_auth?,
            artist: user.artist ? artist_json(user.artist) : nil
          }
        end
        
        def artist_json(artist)
          {
            id: artist.id,
            name: artist.name,
            verified: artist.verified,
            avatar_url: artist.avatar_url
          }
        end
      end
    end
  end
end

