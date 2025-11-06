module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json
        
        # POST /api/v1/auth/sign_in
        # Body (Email): { email: "...", password: "..." }
        # Body (Wallet): { wallet_address: "...", signature: "...", message: "..." }
        def create
          # Determine auth method
          if params[:wallet_address].present?
            sign_in_with_wallet
          elsif params[:email].present?
            sign_in_with_email
          else
            render json: { error: 'Must provide either email/password or wallet credentials' }, status: :unprocessable_entity
          end
        end
        
        private
        
        def sign_in_with_wallet
          wallet_address = params[:wallet_address]
          signature = params[:signature]
          message = params[:message]
          
          unless wallet_address && signature && message
            return render json: { error: 'Missing wallet credentials' }, status: :unprocessable_entity
          end
          
          # TODO: Verify Solana signature (implement in SolanaService)
          
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
        
        def sign_in_with_email
          email = params[:email]
          password = params[:password]
          
          unless email && password
            return render json: { error: 'Email and password required' }, status: :unprocessable_entity
          end
          
          user = User.find_by(email: email)
          
          unless user
            return render json: { error: 'User not found. Please sign up first.' }, status: :not_found
          end
          
          unless user.valid_password?(password)
            return render json: { error: 'Invalid email or password' }, status: :unauthorized
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

