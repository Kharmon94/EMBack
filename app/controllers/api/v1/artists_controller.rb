module Api
  module V1
    class ArtistsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show, :albums, :events, :livestreams, :tokens]
      load_and_authorize_resource except: [:index, :show, :albums, :events, :livestreams, :tokens]
      skip_authorization_check only: [:index, :show, :albums, :events, :livestreams, :tokens]
      
      # GET /api/v1/artists
      def index
        @artists = Artist.includes(:user, :artist_token)
        
        # Filter by verified
        @artists = @artists.verified if params[:verified] == 'true'
        
        # Search by name
        @artists = @artists.where('name ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        
        # Order
        @artists = case params[:sort]
                   when 'followers' then @artists.left_joins(:follows).group(:id).order('COUNT(follows.id) DESC')
                   when 'recent' then @artists.order(created_at: :desc)
                   else @artists.order(name: :asc)
                   end
        
        @paginated = paginate(@artists)
        
        render json: {
          artists: @paginated.map { |artist| artist_json(artist) },
          meta: pagination_meta(@artists, @paginated)
        }
      end
      
      # GET /api/v1/artists/:id
      def show
        @artist = Artist.includes(:user, :artist_token).find(params[:id])
        render json: {
          artist: detailed_artist_json(@artist),
          stats: artist_stats(@artist)
        }
      end
      
      # PATCH /api/v1/artists/:id
      def update
        if @artist.update(artist_params)
          render json: { artist: detailed_artist_json(@artist) }
        else
          render json: { errors: @artist.errors }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/artists/:id/albums
      def albums
        @artist = Artist.find(params[:id])
        @albums = @artist.albums.includes(:tracks).released.order(release_date: :desc)
        render json: { albums: @albums.map { |album| album_json(album) } }
      end
      
      # GET /api/v1/artists/:id/events
      def events
        @artist = Artist.find(params[:id])
        @events = @artist.events.upcoming.order(start_time: :asc)
        render json: { events: @events.map { |event| event_json(event) } }
      end
      
      # GET /api/v1/artists/:id/livestreams
      def livestreams
        @artist = Artist.find(params[:id])
        @livestreams = @artist.livestreams.active.order(start_time: :desc)
        render json: { livestreams: @livestreams.map { |ls| livestream_json(ls) } }
      end
      
      # GET /api/v1/artists/:id/tokens
      def tokens
        @artist = Artist.find(params[:id])
        @token = @artist.artist_token
        render json: { token: @token ? token_json(@token) : nil }
      end
      
      private
      
      def artist_params
        params.require(:artist).permit(:name, :bio, :avatar_url, :banner_url, :twitter_handle, :instagram_handle)
      end
      
      def artist_json(artist)
        {
          id: artist.id,
          name: artist.name,
          bio: artist.bio,
          avatar_url: artist.avatar_url,
          banner_url: artist.banner_url,
          verified: artist.verified,
          twitter_handle: artist.twitter_handle,
          instagram_handle: artist.instagram_handle,
          has_token: artist.artist_token.present?,
          token_address: artist.artist_token&.mint_address
        }
      end
      
      def detailed_artist_json(artist)
        artist_json(artist).merge(
          created_at: artist.created_at,
          followers_count: artist.follows.count,
          albums_count: artist.albums.count,
          events_count: artist.events.count
        )
      end
      
      def artist_stats(artist)
        {
          total_streams: StreamingService.artist_stats(artist, 90.days)[:total_streams],
          total_listeners: StreamingService.artist_stats(artist, 90.days)[:unique_listeners],
          token_holders: artist.artist_token ? artist.artist_token.trades.select(:user_id).distinct.count : 0
        }
      end
      
      def album_json(album)
        {
          id: album.id,
          title: album.title,
          description: album.description,
          cover_url: album.cover_url,
          price: album.price,
          release_date: album.release_date,
          tracks_count: album.tracks.count
        }
      end
      
      def event_json(event)
        {
          id: event.id,
          title: event.title,
          venue: event.venue,
          location: event.location,
          start_time: event.start_time,
          capacity: event.capacity,
          sold_tickets: event.sold_tickets_count,
          is_sold_out: event.is_sold_out?
        }
      end
      
      def livestream_json(livestream)
        {
          id: livestream.id,
          title: livestream.title,
          status: livestream.status,
          viewer_count: livestream.viewer_count,
          start_time: livestream.start_time,
          token_gate_amount: livestream.token_gate_amount
        }
      end
      
      def token_json(token)
        {
          id: token.id,
          name: token.name,
          symbol: token.symbol,
          mint_address: token.mint_address,
          supply: token.supply,
          market_cap: token.market_cap,
          graduated: token.graduated
        }
      end
    end
  end
end

