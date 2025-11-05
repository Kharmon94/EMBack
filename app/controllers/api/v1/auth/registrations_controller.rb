module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json
        skip_before_action :authenticate_user!, only: [:create]
        
        # POST /api/v1/auth/sign_up
        # Body: { wallet_address: "...", signature: "...", role: "fan|artist", artist_name: "..." }
        def create
          wallet_address = params[:wallet_address]
          signature = params[:signature]
          message = params[:message]
          role = params[:role] || 'fan'
          
          unless wallet_address && signature && message
            return render json: { error: 'Missing wallet credentials' }, status: :unprocessable_entity
          end
          
          # TODO: Verify Solana signature (implement in SolanaService)
          
          # Check if user already exists
          if User.exists?(wallet_address: wallet_address)
            return render json: { error: 'Wallet address already registered' }, status: :unprocessable_entity
          end
          
          # Create user
          user = User.new(
            wallet_address: wallet_address,
            email: "#{wallet_address}@solana.wallet", # Temporary email
            password: SecureRandom.hex(32), # Random password (not used for wallet auth)
            role: role
          )
          
          if user.save
            # If artist role, create artist profile
            if role == 'artist' && params[:artist_name].present?
              user.create_artist!(
                name: params[:artist_name],
                bio: params[:artist_bio],
                verified: false
              )
            end
            
            sign_in(user)
            render json: {
              message: 'Account created successfully',
              user: user_json(user)
            }, status: :created
          else
            render json: { error: 'Failed to create account', details: user.errors }, status: :unprocessable_entity
          end
        end
        
        private
        
        def user_json(user)
          {
            id: user.id,
            wallet_address: user.wallet_address,
            role: user.role,
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

