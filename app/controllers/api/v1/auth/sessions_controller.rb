module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json
        
        # POST /api/v1/auth/sign_in
        # Body: { wallet_address: "...", signature: "..." }
        def create
          # Verify Solana wallet signature
          wallet_address = params[:wallet_address]
          signature = params[:signature]
          message = params[:message]
          
          unless wallet_address && signature && message
            return render json: { error: 'Missing wallet credentials' }, status: :unprocessable_entity
          end
          
          # TODO: Verify Solana signature (implement in SolanaService)
          # For now, we'll find or create user by wallet
          
          user = User.find_by(wallet_address: wallet_address)
          
          unless user
            return render json: { error: 'User not found. Please sign up first.' }, status: :not_found
          end
          
          sign_in(user)
          render json: {
            message: 'Signed in successfully',
            user: user_json(user)
          }, status: :ok
        end
        
        # DELETE /api/v1/auth/sign_out
        def destroy
          if current_user
            sign_out(current_user)
            render json: { message: 'Signed out successfully' }, status: :ok
          else
            render json: { error: 'No active session' }, status: :unauthorized
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

