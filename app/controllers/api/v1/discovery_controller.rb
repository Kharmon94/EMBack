module Api
  module V1
    class DiscoveryController < BaseController
      skip_before_action :authenticate_api_user!, only: [:feed, :related, :trending], raise: false
      
      # GET /api/v1/discovery/feed
      def feed
        service = DiscoveryService.new(try(:current_user))
        feed = service.home_feed(params[:limit]&.to_i || 50)
        
        render json: {
          feed: feed,
          meta: {
            count: feed.length,
            timestamp: Time.current
          }
        }
      end
      
      # GET /api/v1/discovery/related/:type/:id
      def related
        service = DiscoveryService.new(try(:current_user))
        item = find_item(params[:type], params[:id])
        
        return render json: { error: 'Item not found' }, status: :not_found unless item
        
        related = service.related_content(item, params[:limit]&.to_i || 10)
        
        render json: {
          related: related
        }
      end
      
      # GET /api/v1/discovery/trending
      def trending
        trending_content = {
          tracks: trending_tracks(10),
          albums: trending_albums(8),
          videos: trending_videos(8),
          minis: trending_minis(10)
        }
        
        render json: trending_content
      end
      
      # GET /api/v1/discovery/friends_activity
      def friends_activity
        return render json: { error: 'Authentication required' }, status: :unauthorized unless current_user
        
        friend_ids = current_user.follows.where(followable_type: 'User', friendship: true).pluck(:followable_id)
        
        activities = UserActivity.where(user_id: friend_ids)
                                .where('created_at > ?', 24.hours.ago)
                                .includes(:activityable, :user)
                                .recent
                                .limit(params[:limit]&.to_i || 20)
        
        render json: {
          activities: activities.map { |a| activity_json(a) }
        }
      end
      
      # GET /api/v1/discovery/continue_watching
      def continue_watching
        return render json: { error: 'Authentication required' }, status: :unauthorized unless current_user
        
        # Get partially watched videos/minis
        incomplete_views = current_user.view_histories
                                      .where(completed: false)
                                      .where('watch_percentage > ?', 10) # At least 10% watched
                                      .includes(:viewable)
                                      .order(updated_at: :desc)
                                      .limit(params[:limit]&.to_i || 10)
        
        render json: {
          continue_watching: incomplete_views.map do |vh|
            {
              id: vh.viewable.id,
              type: vh.viewable_type.underscore,
              content: format_viewable(vh.viewable),
              watch_percentage: vh.watch_percentage,
              last_watched: vh.updated_at
            }
          end
        }
      end
      
      # GET /api/v1/discovery/recently_played
      def recently_played
        return render json: { error: 'Authentication required' }, status: :unauthorized unless current_user
        
        recent = current_user.recently_playeds
                            .includes(:playable)
                            .recent
                            .limit(params[:limit]&.to_i || 20)
        
        render json: {
          recently_played: recent.map do |rp|
            {
              id: rp.playable.id,
              type: rp.playable_type.underscore,
              content: format_playable(rp.playable),
              played_at: rp.created_at
            }
          end
        }
      end
      
      private
      
      def find_item(type, id)
        case type
        when 'track' then Track.find_by(id: id)
        when 'album' then Album.find_by(id: id)
        when 'video' then Video.find_by(id: id)
        when 'mini' then Mini.find_by(id: id)
        when 'event' then Event.find_by(id: id)
        when 'artist' then Artist.find_by(id: id)
        else nil
        end
      end
      
      def trending_tracks(limit)
        Track.joins(:album)
             .joins('LEFT JOIN streams ON streams.track_id = tracks.id AND streams.listened_at > NOW() - INTERVAL \'7 days\'')
             .group('tracks.id', 'albums.id')
             .order('COUNT(streams.id) DESC')
             .limit(limit)
             .map { |t| track_json(t) }
      end
      
      def trending_albums(limit)
        Album.left_joins(tracks: :streams)
             .where('streams.listened_at > ?', 7.days.ago)
             .group('albums.id')
             .order('COUNT(streams.id) DESC')
             .limit(limit)
             .map { |a| album_json(a) }
      end
      
      def trending_videos(limit)
        Video.trending.limit(limit).map { |v| video_json(v) }
      end
      
      def trending_minis(limit)
        Mini.trending.limit(limit).map { |m| mini_json(m) }
      end
      
      def track_json(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          album: { id: track.album.id, title: track.album.title, cover_url: track.album.cover_url },
          artist: { id: track.album.artist.id, name: track.album.artist.name, verified: track.album.artist.verified }
        }
      end
      
      def album_json(album)
        {
          id: album.id,
          title: album.title,
          cover_url: album.cover_url,
          artist: { id: album.artist.id, name: album.artist.name, verified: album.artist.verified }
        }
      end
      
      def video_json(video)
        {
          id: video.id,
          title: video.title,
          thumbnail_url: video.thumbnail_url,
          views_count: video.views_count,
          artist: { id: video.artist.id, name: video.artist.name, verified: video.artist.verified }
        }
      end
      
      def mini_json(mini)
        {
          id: mini.id,
          title: mini.title,
          thumbnail_url: mini.thumbnail_url,
          views_count: mini.views_count,
          likes_count: mini.likes_count,
          artist: { id: mini.artist.id, name: mini.artist.name, verified: mini.artist.verified }
        }
      end
      
      def event_json(event)
        {
          id: event.id,
          title: event.title,
          venue: event.venue,
          location: event.location,
          start_time: event.start_time,
          artist: { id: event.artist.id, name: event.artist.name, verified: event.artist.verified }
        }
      end
      
      def livestream_json(livestream)
        {
          id: livestream.id,
          title: livestream.title,
          start_time: livestream.start_time,
          status: livestream.status,
          artist: { id: livestream.artist.id, name: livestream.artist.name, verified: livestream.artist.verified }
        }
      end
      
      def activity_json(activity)
        {
          id: activity.id,
          type: activity.activity_type,
          user: { id: activity.user.id, email: activity.user.email },
          content: format_activityable(activity.activityable),
          timestamp: activity.created_at
        }
      end
      
      def format_viewable(viewable)
        case viewable
        when Video then video_json(viewable)
        when Mini then mini_json(viewable)
        else {}
        end
      end
      
      def format_playable(playable)
        case playable
        when Track then track_json(playable)
        when Album then album_json(playable)
        when Video then video_json(playable)
        else {}
        end
      end
      
      def format_activityable(activityable)
        case activityable
        when Track then track_json(activityable)
        when Album then album_json(activityable)
        when Video then video_json(activityable)
        when Mini then mini_json(activityable)
        when Event then event_json(activityable)
        when Artist then { id: activityable.id, name: activityable.name, verified: activityable.verified }
        else {}
        end
      end
    end
  end
end

