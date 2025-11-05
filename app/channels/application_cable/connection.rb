module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # Extract token from connection params or headers
      token = request.params[:token] || cookies.encrypted[:token]
      
      if token
        begin
          # Decode JWT token to get user
          decoded_token = JWT.decode(
            token,
            Rails.application.credentials.devise_jwt_secret_key || ENV['DEVISE_JWT_SECRET_KEY'],
            true,
            { algorithm: 'HS256' }
          )
          
          user_id = decoded_token[0]['sub']
          user = User.find_by(id: user_id)
          
          return user if user
        rescue JWT::DecodeError, JWT::ExpiredSignature => e
          Rails.logger.error("JWT decode error: #{e.message}")
        end
      end
      
      # Allow anonymous connections (current_user will be nil)
      # For production, you might want to reject: reject_unauthorized_connection
      nil
    end
  end
end

