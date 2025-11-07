module Api
  module V1
    module Auth
      class SessionsController < BaseController
        skip_before_action :authenticate_api_user!, only: [:create]
        skip_authorization_check
        
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
        
        # DELETE /api/v1/auth/sign_out
        def destroy
          # JWT tokens are stateless, so we just add to denylist
          if current_user
            # Get the JWT from the Authorization header
            token = request.headers['Authorization']&.split(' ')&.last
            if token
              # Decode jti from token
              jti = decode_jti_from_token(token)
              
              # Only add to denylist if jti was successfully decoded
              if jti.present?
                JwtDenylist.create!(jti: jti, exp: Time.current + 1.day)
              end
            end
            render json: { message: 'Signed out successfully' }, status: :ok
          else
            render json: { error: 'No active session' }, status: :unauthorized
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
          
          # Generate JWT token
          token = generate_jwt_token(user)
          
          render json: {
            message: 'Signed in successfully',
            token: token,
            user: user_json(user)
          }, status: :ok
        end
        
        def sign_in_with_email
          email = params[:email]
          password = params[:password]
          
          # Log for debugging
          Rails.logger.info "Sign in attempt - Email present: #{email.present?}, Password present: #{password.present?}"
          
          unless email && password
            return render json: { error: 'Email and password required' }, status: :unprocessable_entity
          end
          
          # Case-insensitive email lookup
          user = User.where('LOWER(email) = ?', email.downcase).first
          
          Rails.logger.info "User found: #{user.present?}, Email searched: #{email}"
          
          unless user
            return render json: { error: 'User not found. Please sign up first.' }, status: :not_found
          end
          
          unless user.valid_password?(password)
            return render json: { error: 'Invalid email or password' }, status: :unauthorized
          end
          
          # Generate JWT token
          token = generate_jwt_token(user)
          
          render json: {
            message: 'Signed in successfully',
            token: token,
            user: user_json(user)
          }, status: :ok
        end
        
        def generate_jwt_token(user)
          # Use Warden::JWTAuth to generate token
          Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
        end
        
        def decode_jti_from_token(token)
          # Decode JWT to get jti claim
          JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base, true, algorithm: 'HS256').first['jti']
        rescue
          nil
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

