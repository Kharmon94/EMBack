module Api
  module V1
    class BaseController < ApplicationController
      # Custom authentication - use Warden directly since we're in API mode
      before_action :authenticate_api_user!
      
      respond_to :json
      
      # CanCanCan authorization
      include CanCan::ControllerAdditions
      check_authorization unless: :devise_controller?
      
      # Override current_ability to handle guest users
      def current_ability
        # Safely get current_user, returns nil if not authenticated
        user = begin
          current_user
        rescue
          nil
        end
        @current_ability ||= ::Ability.new(user)
      end
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from CanCan::AccessDenied, with: :forbidden
      
      private
      
      # Custom authentication for API mode
      def authenticate_api_user!
        token = extract_token_from_header
        
        unless token
          return render json: { error: 'No token provided' }, status: :unauthorized
        end
        
        begin
          decoded = JWT.decode(
            token,
            Rails.application.credentials.devise_jwt_secret_key || ENV['DEVISE_JWT_SECRET_KEY'] || Rails.application.secret_key_base,
            true,
            algorithm: 'HS256'
          )
          
          user_id = decoded.first['sub']
          jti = decoded.first['jti']
          
          # Check if token is in denylist
          if JwtDenylist.exists?(jti: jti)
            return render json: { error: 'Token has been revoked' }, status: :unauthorized
          end
          
          @current_user = User.find_by(id: user_id)
          
          unless @current_user
            render json: { error: 'User not found' }, status: :unauthorized
          end
        rescue JWT::DecodeError => e
          render json: { error: 'Invalid token' }, status: :unauthorized
        rescue => e
          Rails.logger.error "JWT Auth Error: #{e.message}"
          render json: { error: 'Authentication failed' }, status: :unauthorized
        end
      end
      
      # Override current_user
      def current_user
        @current_user
      end
      
      # Extract JWT token from Authorization header
      def extract_token_from_header
        authorization_header = request.headers['Authorization']
        return nil unless authorization_header
        
        # Format: "Bearer <token>"
        authorization_header.split(' ').last if authorization_header.start_with?('Bearer ')
      end
      
      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end
      
      def unprocessable_entity(exception)
        render json: { error: exception.message, details: exception.record&.errors }, status: :unprocessable_entity
      end
      
      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
      
      def forbidden(exception)
        render json: { error: 'Access denied', message: exception.message }, status: :forbidden
      end
      
      def current_artist
        @current_artist ||= current_user&.artist
      end
      
      def require_artist!
        unless current_artist
          render json: { error: 'Artist profile required' }, status: :forbidden
        end
      end
      
      def require_admin!
        unless current_user&.admin?
          render json: { error: 'Admin access required' }, status: :forbidden
        end
      end
      
      # Pagination helpers
      def pagination_params
        {
          page: params[:page] || 1,
          per_page: [params[:per_page]&.to_i || 20, 100].min
        }
      end
      
      def paginate(collection)
        page = pagination_params[:page].to_i
        per_page = pagination_params[:per_page]
        collection.limit(per_page).offset((page - 1) * per_page)
      end
      
      def pagination_meta(collection, paginated)
        # Handle grouped queries where count returns a Hash
        total = collection.count
        total_count = total.is_a?(Hash) ? total.size : total
        
        {
          current_page: pagination_params[:page].to_i,
          per_page: pagination_params[:per_page],
          total_count: total_count,
          total_pages: (total_count.to_f / pagination_params[:per_page]).ceil
        }
      end
    end
  end
end

