module Api
  module V1
    class ReviewsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index], raise: false
      load_and_authorize_resource
      skip_authorization_check only: [:index]
      
      # GET /api/v1/reviews?merch_item_id=X
      def index
        @reviews = Review.includes(:user, :merch_item).recent
        
        @reviews = @reviews.where(merch_item_id: params[:merch_item_id]) if params[:merch_item_id]
        @reviews = @reviews.verified if params[:verified] == 'true'
        @reviews = @reviews.by_rating(params[:rating]) if params[:rating]
        @reviews = @reviews.most_helpful if params[:sort] == 'helpful'
        
        @paginated = paginate(@reviews)
        
        render json: {
          reviews: @paginated.map { |review| review_json(review) },
          meta: pagination_meta(@reviews, @paginated)
        }
      end
      
      # POST /api/v1/reviews
      def create
        @review = current_user.reviews.build(review_params)
        
        # Check if user purchased the item
        if @review.order_id
          order = current_user.orders.find_by(id: @review.order_id)
          if order && order.order_items.exists?(merch_item_id: @review.merch_item_id)
            @review.verified_purchase = true
          end
        end
        
        if @review.save
          render json: { review: review_json(@review), message: 'Review submitted successfully' }, status: :created
        else
          render json: { errors: @review.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/reviews/:id
      def update
        if @review.update(review_update_params)
          render json: { review: review_json(@review) }
        else
          render json: { errors: @review.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/reviews/:id
      def destroy
        @review.destroy
        render json: { message: 'Review deleted successfully' }
      end
      
      # POST /api/v1/reviews/:id/vote
      def vote
        vote = @review.review_votes.find_or_initialize_by(user: current_user)
        vote.helpful = params[:helpful]
        
        if vote.save
          render json: { 
            message: 'Vote recorded',
            helpful_count: @review.helpful_count,
            not_helpful_count: @review.not_helpful_count
          }
        else
          render json: { errors: vote.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/reviews/:id/respond (artist only)
      def respond
        unless current_user.artist_id == @review.merch_item.artist_id || current_user.admin?
          render json: { error: 'Only the seller can respond to reviews' }, status: :forbidden
          return
        end
        
        @review.update!(
          artist_response: params[:response],
          artist_responded_at: Time.current
        )
        
        render json: { review: review_json(@review) }
      end
      
      private
      
      def review_params
        params.require(:review).permit(:merch_item_id, :order_id, :rating, :title, :content)
      end
      
      def review_update_params
        params.require(:review).permit(:title, :content)
      end
      
      def review_json(review)
        {
          id: review.id,
          rating: review.rating,
          title: review.title,
          content: review.content,
          verified_purchase: review.verified_purchase,
          helpful_count: review.helpful_count,
          not_helpful_count: review.not_helpful_count,
          artist_response: review.artist_response,
          artist_responded_at: review.artist_responded_at,
          user: {
            id: review.user.id,
            name: review.user.email&.split('@')&.first || "User #{review.user.id}",
            verified: review.verified_purchase
          },
          created_at: review.created_at,
          updated_at: review.updated_at
        }
      end
    end
  end
end

