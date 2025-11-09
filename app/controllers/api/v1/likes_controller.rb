module Api
  module V1
    class LikesController < BaseController
      skip_authorization_check
      
      # POST /api/v1/:likeable_type/:likeable_id/like
      def create
        likeable_type = params[:likeable_type].classify
        likeable_id = params[:likeable_id]
        
        @likeable = likeable_type.constantize.find(likeable_id)
        @like = current_user.likes.find_or_initialize_by(
          likeable: @likeable
        )
        
        if @like.persisted?
          render json: { message: 'Already liked' }, status: :ok
        elsif @like.save
          render json: {
            message: 'Liked successfully',
            likes_count: @likeable.reload.likes_count
          }, status: :created
        else
          render json: { errors: @like.errors }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Content not found' }, status: :not_found
      end
      
      # DELETE /api/v1/:likeable_type/:likeable_id/like
      def destroy
        likeable_type = params[:likeable_type].classify
        likeable_id = params[:likeable_id]
        
        @likeable = likeable_type.constantize.find(likeable_id)
        @like = current_user.likes.find_by(likeable: @likeable)
        
        if @like
          @like.destroy
          render json: {
            message: 'Unliked successfully',
            likes_count: @likeable.reload.likes_count
          }
        else
          render json: { error: 'Not liked yet' }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Content not found' }, status: :not_found
      end
      
      # GET /api/v1/:likeable_type/:likeable_id/likes
      def index
        likeable_type = params[:likeable_type].classify
        likeable_id = params[:likeable_id]
        
        @likeable = likeable_type.constantize.find(likeable_id)
        @likes = @likeable.likes.includes(:user).order(created_at: :desc).limit(100)
        
        render json: {
          likes_count: @likeable.likes_count,
          liked_by_current_user: current_user ? @likeable.likes.exists?(user: current_user) : false,
          recent_likes: @likes.first(10).map { |like|
            {
              id: like.id,
              user: {
                id: like.user.id,
                username: like.user.email.split('@').first,
                wallet_address: like.user.wallet_address
              },
              created_at: like.created_at
            }
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Content not found' }, status: :not_found
      end
    end
  end
end

