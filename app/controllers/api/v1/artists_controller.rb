module Api
  module V1
    class ArtistsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show, :profile, :albums, :events, :livestreams, :tokens], raise: false
      load_and_authorize_resource except: [:index, :show, :profile, :albums, :events, :livestreams, :tokens]
      skip_authorization_check only: [:index, :show, :profile, :albums, :events, :livestreams, :tokens]
      
      # GET /api/v1/artists
      def index
        @artists = ::Artist.includes(:user, :artist_token)
        
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
      
      # GET /api/v1/artists/:id/profile (Comprehensive showcase)
      def profile
        @artist = Artist.includes(
          :user,
          :artist_token,
          :albums,
          :events,
          :livestreams,
          :merch_items,
          :fan_passes
        ).find(params[:id])
        
        render json: {
          artist: {
            id: @artist.id,
            name: @artist.name,
            bio: @artist.bio,
            avatar_url: @artist.avatar_url,
            banner_url: @artist.banner_url,
            verified: @artist.verified,
            location: @artist.location,
            genres: @artist.genres,
            member_since: @artist.created_at,
            social_links: @artist.user.social_links || {}
          },
          stats: {
            followers_count: @artist.follows.count,
            following_count: @artist.user.follows.count,
            total_streams: @artist.albums.joins(:tracks).joins('INNER JOIN streams ON streams.track_id = tracks.id').count,
            monthly_listeners: @artist.albums.joins(:tracks).joins('INNER JOIN streams ON streams.track_id = tracks.id').where('streams.created_at > ?', 30.days.ago).select('DISTINCT streams.user_id').count,
            total_albums: @artist.albums.count,
            total_tracks: @artist.albums.joins(:tracks).count,
            total_videos: @artist.videos.published.count,
            total_video_views: @artist.videos.sum(:views_count),
            total_minis: @artist.minis.published.count,
            total_mini_views: @artist.minis.sum(:views_count),
            total_mini_shares: @artist.minis.sum(:shares_count),
            total_events: @artist.events.count,
            active_fan_passes: @artist.fan_passes.where(active: true).count,
            total_comments: Comment.where(commentable: @artist.albums).or(Comment.where(commentable: @artist.events)).or(Comment.where(commentable: @artist.livestreams)).or(Comment.where(commentable: @artist.videos)).or(Comment.where(commentable: @artist.minis)).count,
            total_likes: Like.where(likeable: @artist.albums).or(Like.where(likeable: Track.joins(:album).where(albums: { artist_id: @artist.id }))).or(Like.where(likeable: @artist.videos)).or(Like.where(likeable: @artist.minis)).count
          },
          token: @artist.artist_token ? {
            name: @artist.artist_token.name,
            symbol: @artist.artist_token.symbol,
            mint_address: @artist.artist_token.mint_address,
            current_price: @artist.artist_token.current_price,
            market_cap: @artist.artist_token.market_cap,
            holders_count: @artist.artist_token.holders_count,
            price_change_24h: calculate_price_change(@artist.artist_token)
          } : nil,
          albums: @artist.albums.released.order(release_date: :desc).limit(10).map { |album|
            {
              id: album.id,
              title: album.title,
              cover_url: album.cover_url,
              release_date: album.release_date,
              track_count: album.tracks.count,
              likes_count: album.likes_count
            }
          },
          upcoming_events: @artist.events.upcoming.order(start_time: :asc).limit(5).map { |event|
            {
              id: event.id,
              title: event.title,
              start_time: event.start_time,
              venue: event.venue,
              ticket_tiers: event.ticket_tiers.map { |tier| { id: tier.id, name: tier.name, price: tier.price_sol, available: tier.available } }
            }
          },
          recent_livestreams: @artist.livestreams.where(status: :ended).order(ended_at: :desc).limit(3).map { |stream|
            {
              id: stream.id,
              title: stream.title,
              status: stream.status,
              viewer_count: stream.viewer_count,
              ended_at: stream.ended_at
            }
          },
          upcoming_livestreams: @artist.livestreams.upcoming.order(start_time: :asc).limit(3).map { |stream|
            {
              id: stream.id,
              title: stream.title,
              start_time: stream.start_time
            }
          },
          merch_items: @artist.merch_items.order(created_at: :desc).limit(6).map { |merch|
            {
              id: merch.id,
              name: merch.name,
              price: merch.price,
              image_url: merch.image_url,
              stock: merch.stock
            }
          },
          videos: @artist.videos.published.order(published_at: :desc).limit(6).map { |video|
            {
              id: video.id,
              title: video.title,
              duration: video.duration,
              thumbnail_url: video.thumbnail_url,
              views_count: video.views_count,
              likes_count: video.likes_count,
              access_tier: video.access_tier,
              price: video.price
            }
          },
          minis: @artist.minis.published.order(published_at: :desc).limit(12).map { |mini|
            {
              id: mini.id,
              title: mini.title,
              duration: mini.duration,
              thumbnail_url: mini.thumbnail_url,
              views_count: mini.views_count,
              likes_count: mini.likes_count,
              shares_count: mini.shares_count,
              access_tier: mini.access_tier,
              price: mini.price,
              engagement_rate: mini.engagement_rate
            }
          },
          fan_passes: @artist.fan_passes.where(active: true).map { |pass|
            {
              id: pass.id,
              name: pass.name,
              price: pass.price,
              minted_count: pass.minted_count,
              max_supply: pass.max_supply,
              dividend_percentage: pass.dividend_percentage,
              perks_count: pass.total_perks_count
            }
          },
          is_following: current_user ? Follow.exists?(user: current_user, artist: @artist) : false
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
      
      def calculate_price_change(token)
        # Calculate 24h price change
        # TODO: Implement actual 24h price tracking
        0.0 # Placeholder
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

