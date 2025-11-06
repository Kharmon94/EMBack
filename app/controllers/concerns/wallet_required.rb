module WalletRequired
  extend ActiveSupport::Concern
  
  included do
    before_action :require_wallet_connection, only: []
  end
  
  private
  
  def require_wallet_connection
    return if current_user&.can_perform_blockchain_actions?
    
    if current_user
      # User is authenticated but hasn't linked a wallet
      render json: {
        requires_wallet: true,
        message: 'This action requires a Solana wallet. Please connect your wallet to continue.',
        user_has_account: true
      }, status: :forbidden
    else
      # User is not authenticated at all
      render json: {
        requires_auth: true,
        message: 'Please sign in or create an account to continue.',
        user_has_account: false
      }, status: :unauthorized
    end
  end
  
  def check_wallet_for_action(action_name)
    unless current_user&.can_perform_blockchain_actions?
      if current_user
        render json: {
          requires_wallet: true,
          message: "Connecting your wallet is required to #{action_name}.",
          user_has_account: true
        }, status: :forbidden
        return false
      else
        render json: {
          requires_auth: true,
          message: 'Please sign in or create an account to continue.',
          user_has_account: false
        }, status: :unauthorized
        return false
      end
    end
    true
  end
end

