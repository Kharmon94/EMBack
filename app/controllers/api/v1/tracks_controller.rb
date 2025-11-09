module Api
  module V1
    class TracksController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show, :stream, :log_stream, :is_liked], raise: false
      load_and_authorize_resource except: [:log_stream, :index, :show, :stream, :is_liked]
      skip_authorization_check only: [:index, :show, :stream, :log_stream, :is_liked]
      
      # GET /api/v1/tracks
      def index
        @tracks = Track.includes(:album, album: :artist)
        
        # Filter by album
        @tracks = @tracks.where(album_id: params[:album_id]) if params[:album_id]
        
        # Search
        @tracks = @tracks.where('title ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        
        # Filter explicit content
        @tracks = @tracks.clean if params[:clean] == 'true'
        
        # ADVANCED FILTERS
        # Genre filter
        @tracks = @tracks.joins(:track_genres).where(track_genres: { genre_id: params[:genre_ids] }) if params[:genre_ids].present?
        
        # Mood filter
        @tracks = @tracks.joins(:track_moods).where(track_moods: { mood_id: params[:mood_ids] }) if params[:mood_ids].present?
        
        # Duration range (in seconds)
        @tracks = @tracks.where('duration >= ?', params[:min_duration]) if params[:min_duration].present?
        @tracks = @tracks.where('duration <= ?', params[:max_duration]) if params[:max_duration].present?
        
        # Access tier filter
        @tracks = @tracks.where(access_tier: params[:access_tier]) if params[:access_tier].present?
        
        # Artist verification
        @tracks = @tracks.joins(album: :artist).where(artists: { verified: true }) if params[:verified_only] == 'true'
        
        # Sort
        @tracks = case params[:sort]
                 when 'popular' then @tracks.joins(:streams).group('tracks.id').order('COUNT(streams.id) DESC')
                 when 'recent' then @tracks.order(created_at: :desc)
                 when 'title' then @tracks.order(title: :asc)
                 else @tracks.order(created_at: :desc)
                 end
        
        @paginated = paginate(@tracks)
        
        render json: {
          tracks: @paginated.map { |track| track_json(track) },
          meta: pagination_meta(@tracks, @paginated)
        }
      end
      
      # GET /api/v1/tracks/:id
      def show
        @track = Track.includes(:album, album: :artist).find(params[:id])
        render json: { track: detailed_track_json(@track) }
      end
      
      # GET /api/v1/tracks/:id/stream
      def stream
        @track = Track.find(params[:id])
        
        # Check access permissions
        user = try(:current_user)
        if user
          streaming_service = StreamingService.new(user, @track)
          access = streaming_service.check_access
        else
          # Guest users: check if track is publicly accessible
          case @track.access_tier
          when 'free'
            access = {
              allowed: true,
              quality: @track.free_quality,
              duration: 'unlimited',
              downloadable: false,
              tier: 'free'
            }
          when 'preview_only'
            access = {
              allowed: true,
              quality: 'preview',
              duration: 30,
              downloadable: false,
              tier: 'preview'
            }
          else
            access = {
              allowed: false,
              reason: 'Login or NFT ownership required',
              tier: 'locked'
            }
          end
        end
        
        unless access[:allowed]
          return render json: {
            error: access[:reason],
            purchase_url: access[:purchase_url],
            message: 'This track requires NFT ownership'
          }, status: :forbidden
        end
        
        # For demo purposes, return a test audio URL
        # In production, this would return a signed IPFS gateway URL based on quality
        url = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
        
        render json: {
          url: url,
          track: track_json(@track),
          access: access,
          message: 'Remember to log stream after 30 seconds'
        }
      end
      
      # GET /api/v1/tracks/:id/is_liked
      def is_liked
        @track = Track.find(params[:id])
        
        if current_user
          liked = Like.exists?(user: current_user, likeable: @track)
          render json: { is_liked: liked }
        else
          render json: { is_liked: false }
        end
      end
      
      # POST /api/v1/tracks/:id/log_stream
      def log_stream
        @track = Track.find(params[:id])
        duration = params[:duration].to_i
        
        # Only log if user is authenticated (optional for demo)
        if try(:current_user)
          result = StreamingService.log_stream(current_user, @track, duration)
          
          if result
            render json: { message: 'Stream logged successfully' }
          else
            render json: { message: 'Stream not eligible or already logged' }, status: :unprocessable_entity
          end
        else
          # Guest users - just acknowledge without logging
          render json: { message: 'Stream acknowledged (login to earn royalties)' }
        end
      end
      
      # POST /api/v1/tracks/:id/purchase
      def purchase
        authorize! :create, Purchase
        
        # Verify payment transaction
        signature = params[:transaction_signature]
        
        unless signature
          return render json: { error: 'Transaction signature required' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        
        @purchase = Purchase.create!(
          user: current_user,
          purchasable: @track,
          price_paid: @track.price || @track.album.price
        )
        
        render json: {
          purchase: purchase_json(@purchase),
          message: 'Track purchased successfully',
          download_url: IpfsService.new.signed_url(@track.audio_cid, 24.hours)
        }
      end
      
      # PATCH /api/v1/tracks/:id/update_access
      def update_access
        @track = Track.find(params[:id])
        authorize! :update, @track
        
        # Ensure user is the artist who owns this track
        unless current_user.artist && @track.album.artist_id == current_user.artist.id
          return render json: { error: 'Only the artist can update track access' }, status: :forbidden
        end
        
        if @track.update(access_params)
          render json: {
            track: track_with_access_json(@track),
            message: 'Track access updated successfully'
          }
        else
          render json: { errors: @track.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def access_params
        params.require(:track).permit(:access_tier, :free_quality)
      end
      
      def track_json(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          track_number: track.track_number,
          explicit: track.explicit,
          price: track.price,
          access_tier: track.access_tier,
          requires_nft: track.requires_nft?,
          album: track.album ? {
            id: track.album.id,
            title: track.album.title,
            cover_url: track.album.cover_url
          } : nil,
          artist: track.album&.artist ? {
            id: track.album.artist.id,
            name: track.album.artist.name,
            avatar_url: track.album.artist.avatar_url,
            verified: track.album.artist.verified
          } : nil
        }
      end
      
      def detailed_track_json(track)
        track_json(track).merge(
          isrc: track.isrc,
          audio_url: track.audio_url,
          streams_count: track.eligible_streams_count,
          unique_listeners: track.unique_listeners,
          free_quality: track.free_quality
        )
      end
      
      def track_with_access_json(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          track_number: track.track_number,
          access_tier: track.access_tier,
          free_quality: track.free_quality,
          publicly_accessible: track.publicly_accessible?,
          requires_nft: track.requires_nft?
        }
      end
      
      def purchase_json(purchase)
        {
          id: purchase.id,
          price_paid: purchase.price_paid,
          purchased_at: purchase.created_at
        }
      end
    end
  end
end

