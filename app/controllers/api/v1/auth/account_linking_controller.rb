module Api
  module V1
    module Auth
      class AccountLinkingController < BaseController
        skip_authorization_check
        
        # POST /api/v1/auth/link_wallet
        # Body: { wallet_address: "...", signature: "...", message: "..." }
        def link_wallet
          wallet_address = params[:wallet_address]
          signature = params[:signature]
          message = params[:message]
          
          unless wallet_address && signature && message
            return render json: { error: 'Missing wallet credentials' }, status: :unprocessable_entity
          end
          
          # Check if wallet is already linked to another account
          if User.exists?(wallet_address: wallet_address)
            return render json: { error: 'Wallet already linked to another account' }, status: :unprocessable_entity
          end
          
          # Check if user already has a wallet
          if current_user.wallet_address.present?
            return render json: { error: 'Account already has a wallet linked' }, status: :unprocessable_entity
          end
          
          # TODO: Verify Solana signature (implement in SolanaService)
          
          # Link wallet to account
          if current_user.update(wallet_address: wallet_address)
            render json: {
              message: 'Wallet linked successfully',
              user: user_json(current_user)
            }, status: :ok
          else
            render json: { error: 'Failed to link wallet', details: current_user.errors }, status: :unprocessable_entity
          end
        end
        
        # POST /api/v1/auth/link_email
        # Body: { email: "...", password: "..." }
        def link_email
          email = params[:email]
          password = params[:password]
          
          unless email && password
            return render json: { error: 'Email and password required' }, status: :unprocessable_entity
          end
          
          # Check if email is already linked to another account
          if User.exists?(email: email)
            return render json: { error: 'Email already linked to another account' }, status: :unprocessable_entity
          end
          
          # Check if user already has email
          if current_user.email.present?
            return render json: { error: 'Account already has an email linked' }, status: :unprocessable_entity
          end
          
          # Link email to account
          if current_user.update(email: email, password: password)
            render json: {
              message: 'Email linked successfully',
              user: user_json(current_user)
            }, status: :ok
          else
            render json: { error: 'Failed to link email', details: current_user.errors }, status: :unprocessable_entity
          end
        end
        
        # GET /api/v1/auth/me
        def me
          render json: {
            user: user_json(current_user)
          }, status: :ok
        end
        
        private
        
        def user_json(user)
          {
            id: user.id,
            email: user.email,
            wallet_address: user.wallet_address,
            role: user.role,
            auth_methods: user.auth_methods,
            has_email_auth: user.has_email_auth?,
            has_wallet_auth: user.has_wallet_auth?,
            can_perform_blockchain_actions: user.can_perform_blockchain_actions?,
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

