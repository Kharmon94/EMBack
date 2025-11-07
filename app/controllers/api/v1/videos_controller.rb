module Api
  module V1
    class VideosController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show, :watch], raise: false
      load_and_authorize_resource except: [:index, :show, :watch, :log_view]
      skip_authorization_check only: [:index, :show, :watch]
      before_action :set_video, only: [:show, :update, :destroy, :watch, :log_view, :publish]
      
      # GET /api/v1/videos
      def index
        @videos = Video.published.includes(:artist)
        
        # Filter by artist
        @videos = @videos.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # ADVANCED FILTERS
        # Genre filter
        @videos = @videos.joins(:video_genres).where(video_genres: { genre_id: params[:genre_ids] }) if params[:genre_ids].present?
        
        # Duration category
        if params[:duration_category].present?
          @videos = case params[:duration_category]
                   when 'short' then @videos.where('duration < ?', 300)
                   when 'medium' then @videos.where('duration BETWEEN ? AND ?', 300, 1200)
                   when 'long' then @videos.where('duration > ?', 1200)
                   else @videos
                   end
        end
        
        # Duration range
        @videos = @videos.where('duration >= ?', params[:min_duration]) if params[:min_duration].present?
        @videos = @videos.where('duration <= ?', params[:max_duration]) if params[:max_duration].present?
        
        # View count range
        @videos = @videos.where('views_count >= ?', params[:min_views]) if params[:min_views].present?
        
        # Upload date range
        @videos = @videos.where('published_at >= ?', params[:from_date]) if params[:from_date].present?
        @videos = @videos.where('published_at <= ?', params[:to_date]) if params[:to_date].present?
        
        # Access tier
        @videos = @videos.where(access_tier: params[:access_tier]) if params[:access_tier].present?
        
        # Sort
        @videos = case params[:sort]
                  when 'recent' then @videos.recent
                  when 'popular' then @videos.popular
                  when 'trending' then @videos.trending
                  else @videos.recent
                  end
        
        @paginated = paginate(@videos)
        
        render json: {
          videos: @paginated.map { |v| video_json(v) },
          meta: pagination_meta(@videos, @paginated)
        }
      end
      
      # GET /api/v1/videos/:id
      def show
        render json: {
          video: detailed_video_json(@video),
          access: check_access(@video, current_user)
        }
      end
      
      # POST /api/v1/videos
      def create
        @video = current_artist.videos.build(video_params)
        
        if @video.save
          render json: {
            video: detailed_video_json(@video),
            message: 'Video created successfully'
          }, status: :created
        else
          render json: { errors: @video.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/videos/:id
      def update
        authorize! :update, @video
        
        if @video.update(video_params)
          render json: {
            video: detailed_video_json(@video),
            message: 'Video updated successfully'
          }
        else
          render json: { errors: @video.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/videos/:id
      def destroy
        authorize! :destroy, @video
        
        @video.destroy
        render json: { message: 'Video deleted successfully' }
      end
      
      # POST /api/v1/videos/:id/publish
      def publish
        authorize! :update, @video
        
        @video.publish!
        render json: {
          video: detailed_video_json(@video),
          message: 'Video published successfully'
        }
      end
      
      # GET /api/v1/videos/:id/watch
      def watch
        access = check_access(@video, current_user)
        
        unless access[:allowed]
          return render json: {
            error: access[:error],
            access: access
          }, status: :forbidden
        end
        
        # Increment view count
        @video.increment_views!
        
        render json: {
          video_url: @video.video_url,
          duration_allowed: access[:duration],
          quality: access[:quality],
          access_tier: access[:tier]
        }
      end
      
      # POST /api/v1/videos/:id/log_view
      def log_view
        authorize! :create, VideoView
        
        nft_holder = current_user && @video.owns_nft?(current_user)
        
        view = @video.video_views.create!(
          user: current_user,
          watched_duration: params[:watched_duration].to_i,
          nft_holder: nft_holder,
          access_tier: params[:access_tier] || 'free'
        )
        
        view.check_completion
        
        render json: {
          message: 'View logged',
          completed: view.completed
        }
      end
      
      # POST /api/v1/videos/:id/purchase
      def purchase
        authorize! :create, Purchase
        
        unless @video.paid? || @video.preview_only?
          return render json: { error: 'Video is not for sale' }, status: :unprocessable_entity
        end
        
        # Verify Solana transaction
        signature = params[:transaction_signature]
        unless signature
          return render json: { error: 'Transaction signature required' }, status: :bad_request
        end
        
        # TODO: Verify transaction on-chain
        
        # Create purchase record
        purchase = Purchase.create!(
          user: current_user,
          purchasable: @video,
          price_paid: @video.price,
          transaction_signature: signature
        )
        
        render json: {
          message: 'Video purchased successfully',
          purchase: {
            id: purchase.id,
            video: video_json(@video),
            amount: purchase.amount,
            transaction_signature: signature
          }
        }, status: :created
      end
      
      private
      
      def set_video
        @video = Video.find(params[:id])
      end
      
      def video_params
        params.require(:video).permit(
          :title, :description, :duration, :video_url, :thumbnail_url,
          :price, :access_tier, :preview_duration
        )
      end
      
      def check_access(video, user)
        # NFT/Fan pass holders get full access
        if user && video.owns_nft?(user)
          return {
            allowed: true,
            tier: 'premium',
            quality: 'hd',
            duration: video.duration,
            reason: 'NFT holder'
          }
        end
        
        # Check if user purchased
        if user && video.user_purchased?(user)
          return {
            allowed: true,
            tier: 'purchased',
            quality: 'hd',
            duration: video.duration,
            reason: 'Purchased'
          }
        end
        
        # Check access tier
        case video.access_tier
        when 'free'
          {
            allowed: true,
            tier: 'free',
            quality: 'sd',
            duration: video.duration,
            reason: 'Free content'
          }
        when 'preview_only'
          {
            allowed: true,
            tier: 'preview',
            quality: 'sd',
            duration: video.preview_duration,
            reason: 'Preview available',
            purchase_required: true,
            price: video.price
          }
        when 'nft_required'
          {
            allowed: false,
            tier: 'locked',
            error: 'NFT or fan pass ownership required',
            purchase_url: "/fan-passes"
          }
        when 'paid'
          {
            allowed: false,
            tier: 'locked',
            error: 'Purchase required to watch',
            purchase_required: true,
            price: video.price
          }
        end
      end
      
      def video_json(video)
        {
          id: video.id,
          title: video.title,
          description: video.description,
          duration: video.duration,
          thumbnail_url: video.thumbnail_url,
          price: video.price,
          access_tier: video.access_tier,
          views_count: video.views_count,
          likes_count: video.likes_count,
          published: video.published,
          published_at: video.published_at,
          artist: {
            id: video.artist.id,
            name: video.artist.name,
            avatar_url: video.artist.avatar_url,
            verified: video.artist.verified
          }
        }
      end
      
      def detailed_video_json(video)
        video_json(video).merge(
          preview_duration: video.preview_duration,
          created_at: video.created_at,
          updated_at: video.updated_at
        )
      end
    end
  end
end

