module Api
  module V1
    class MinisController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show, :watch, :feed, :trending, :following], raise: false
      load_and_authorize_resource except: [:index, :show, :watch, :log_view, :feed, :trending, :following]
      skip_authorization_check only: [:index, :show, :watch, :feed, :trending, :following]
      before_action :set_mini, only: [:show, :update, :destroy, :watch, :log_view, :publish, :share]
      
      # GET /api/v1/minis
      def index
        @minis = Mini.published.includes(:artist)
        
        # Filter by artist
        @minis = @minis.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Sort
        @minis = case params[:sort]
                 when 'recent' then @minis.recent
                 when 'popular' then @minis.popular
                 when 'trending' then @minis.trending
                 else @minis.recent
                 end
        
        @paginated = paginate(@minis)
        
        render json: {
          minis: @paginated.map { |m| mini_json(m) },
          meta: pagination_meta(@minis, @paginated)
        }
      end
      
      # GET /api/v1/minis/feed - For You personalized feed
      def feed
        @minis = Mini.for_you(current_user)
        
        render json: {
          minis: @minis.map { |m| mini_json(m) }
        }
      end
      
      # GET /api/v1/minis/trending
      def trending
        @minis = Mini.trending.includes(:artist)
        
        render json: {
          minis: @minis.map { |m| mini_json(m) }
        }
      end
      
      # GET /api/v1/minis/following - From followed artists
      def following
        if current_user
          followed_artist_ids = current_user.follows.where(followable_type: 'Artist').pluck(:followable_id)
          @minis = Mini.published
            .where(artist_id: followed_artist_ids)
            .includes(:artist)
            .order(published_at: :desc)
            .limit(100)
        else
          @minis = []
        end
        
        render json: {
          minis: @minis.map { |m| mini_json(m) }
        }
      end
      
      # GET /api/v1/minis/:id
      def show
        render json: {
          mini: detailed_mini_json(@mini),
          access: check_access(@mini, current_user)
        }
      end
      
      # POST /api/v1/minis
      def create
        @mini = current_artist.minis.build(mini_params)
        
        if @mini.save
          render json: {
            mini: detailed_mini_json(@mini),
            message: 'Mini created successfully'
          }, status: :created
        else
          render json: { errors: @mini.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/minis/:id
      def update
        authorize! :update, @mini
        
        if @mini.update(mini_params)
          render json: {
            mini: detailed_mini_json(@mini),
            message: 'Mini updated successfully'
          }
        else
          render json: { errors: @mini.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/minis/:id
      def destroy
        authorize! :destroy, @mini
        
        @mini.destroy
        render json: { message: 'Mini deleted successfully' }
      end
      
      # POST /api/v1/minis/:id/publish
      def publish
        authorize! :update, @mini
        
        @mini.publish!
        render json: {
          mini: detailed_mini_json(@mini),
          message: 'Mini published successfully'
        }
      end
      
      # GET /api/v1/minis/:id/watch
      def watch
        access = check_access(@mini, current_user)
        
        unless access[:allowed]
          return render json: {
            error: access[:error],
            access: access
          }, status: :forbidden
        end
        
        # Increment view count
        @mini.increment_views!
        
        render json: {
          video_url: @mini.video_url,
          duration_allowed: access[:duration],
          quality: access[:quality],
          access_tier: access[:tier]
        }
      end
      
      # POST /api/v1/minis/:id/log_view
      def log_view
        authorize! :create, MiniView
        
        nft_holder = current_user && @mini.owns_nft?(current_user)
        
        view = @mini.mini_views.create!(
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
      
      # POST /api/v1/minis/:id/share
      def share
        @mini.increment_shares!
        
        render json: {
          message: 'Share counted',
          shares_count: @mini.shares_count,
          share_url: "#{request.base_url}/minis/#{@mini.id}"
        }
      end
      
      # POST /api/v1/minis/:id/purchase
      def purchase
        authorize! :create, Purchase
        
        unless @mini.paid? || @mini.preview_only?
          return render json: { error: 'Mini is not for sale' }, status: :unprocessable_entity
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
          purchasable: @mini,
          price_paid: @mini.price,
          transaction_signature: signature
        )
        
        render json: {
          message: 'Mini purchased successfully',
          purchase: {
            id: purchase.id,
            mini: mini_json(@mini),
            amount: purchase.price_paid,
            transaction_signature: signature
          }
        }, status: :created
      end
      
      private
      
      def set_mini
        @mini = Mini.find(params[:id])
      end
      
      def mini_params
        params.require(:mini).permit(
          :title, :description, :duration, :video_url, :thumbnail_url,
          :price, :access_tier, :preview_duration, :aspect_ratio
        )
      end
      
      def check_access(mini, user)
        # NFT/Fan pass holders get full access
        if user && mini.owns_nft?(user)
          return {
            allowed: true,
            tier: 'premium',
            quality: 'hd',
            duration: mini.duration,
            reason: 'NFT holder'
          }
        end
        
        # Check if user purchased
        if user && mini.user_purchased?(user)
          return {
            allowed: true,
            tier: 'purchased',
            quality: 'hd',
            duration: mini.duration,
            reason: 'Purchased'
          }
        end
        
        # Check access tier
        case mini.access_tier
        when 'free'
          {
            allowed: true,
            tier: 'free',
            quality: 'sd',
            duration: mini.duration,
            reason: 'Free content'
          }
        when 'preview_only'
          {
            allowed: true,
            tier: 'preview',
            quality: 'sd',
            duration: mini.preview_duration,
            reason: 'Preview available',
            purchase_required: true,
            price: mini.price
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
            price: mini.price
          }
        end
      end
      
      def mini_json(mini)
        {
          id: mini.id,
          title: mini.title,
          description: mini.description,
          duration: mini.duration,
          thumbnail_url: mini.thumbnail_url,
          price: mini.price,
          access_tier: mini.access_tier,
          aspect_ratio: mini.aspect_ratio,
          views_count: mini.views_count,
          likes_count: mini.likes_count,
          shares_count: mini.shares_count,
          published: mini.published,
          published_at: mini.published_at,
          engagement_rate: mini.engagement_rate,
          artist: {
            id: mini.artist.id,
            name: mini.artist.name,
            avatar_url: mini.artist.avatar_url,
            verified: mini.artist.verified
          }
        }
      end
      
      def detailed_mini_json(mini)
        mini_json(mini).merge(
          preview_duration: mini.preview_duration,
          completion_rate: mini.completion_rate,
          created_at: mini.created_at,
          updated_at: mini.updated_at
        )
      end
    end
  end
end

