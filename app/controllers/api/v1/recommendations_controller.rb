module Api
  module V1
    class RecommendationsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:tracks, :albums, :videos, :minis, :events, :livestreams, :related, :similar], raise: false
      
      # GET /api/v1/recommendations/tracks
      def tracks
        service = RecommendationService.new(try(:current_user))
        tracks = service.tracks_for_you(params[:limit]&.to_i || 50)
        
        render json: {
          tracks: tracks.map { |track| track_json(track) }
        }
      end
      
      # GET /api/v1/recommendations/albums
      def albums
        service = RecommendationService.new(try(:current_user))
        albums = service.albums_for_you(params[:limit]&.to_i || 30)
        
        render json: {
          albums: albums.map { |album| album_json(album) }
        }
      end
      
      # GET /api/v1/recommendations/videos
      def videos
        service = RecommendationService.new(try(:current_user))
        videos = service.videos_for_you(params[:limit]&.to_i || 20)
        
        render json: {
          videos: videos.map { |video| video_json(video) }
        }
      end
      
      # GET /api/v1/recommendations/minis
      def minis
        service = RecommendationService.new(try(:current_user))
        minis = service.minis_for_you(params[:limit]&.to_i || 50)
        
        render json: {
          minis: minis.map { |mini| mini_json(mini) }
        }
      end
      
      # GET /api/v1/recommendations/events
      def events
        service = RecommendationService.new(try(:current_user))
        events = service.events_for_you(params[:limit]&.to_i || 20)
        
        render json: {
          events: events.map { |event| event_json(event) }
        }
      end
      
      # GET /api/v1/recommendations/livestreams
      def livestreams
        service = RecommendationService.new(try(:current_user))
        livestreams = service.livestreams_for_you(params[:limit]&.to_i || 15)
        
        render json: {
          livestreams: livestreams.map { |ls| livestream_json(ls) }
        }
      end
      
      # GET /api/v1/recommendations/similar/:type/:id
      def similar
        service = RecommendationService.new(try(:current_user))
        
        item = find_item(params[:type], params[:id])
        return render json: { error: 'Item not found' }, status: :not_found unless item
        
        similar_items = case params[:type]
                       when 'track' then service.similar_tracks(item, params[:limit]&.to_i || 20)
                       when 'album' then service.similar_albums(item, params[:limit]&.to_i || 12)
                       when 'video' then service.similar_videos(item, params[:limit]&.to_i || 12)
                       when 'mini' then service.similar_minis(item, params[:limit]&.to_i || 20)
                       when 'event' then service.similar_events(item, params[:limit]&.to_i || 10)
                       else []
                       end
        
        render json: {
          similar: similar_items.map { |si| format_item(si) }
        }
      end
      
      # GET /api/v1/recommendations/related/:type/:id
      def related
        service = DiscoveryService.new(try(:current_user))
        
        item = find_item(params[:type], params[:id])
        return render json: { error: 'Item not found' }, status: :not_found unless item
        
        related_content = service.related_content(item, params[:limit]&.to_i || 10)
        
        render json: {
          related: related_content
        }
      end
      
      # GET /api/v1/recommendations/because_you_liked/:type/:id
      def because_you_liked
        return render json: { error: 'Authentication required' }, status: :unauthorized unless current_user
        
        service = DiscoveryService.new(current_user)
        item = find_item(params[:type], params[:id])
        return render json: { error: 'Item not found' }, status: :not_found unless item
        
        suggestions = service.because_you_liked(item, params[:limit]&.to_i || 10)
        
        render json: {
          suggestions: suggestions
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
      
      def format_item(item)
        case item
        when Track then track_json(item)
        when Album then album_json(item)
        when Video then video_json(item)
        when Mini then mini_json(item)
        when Event then event_json(item)
        else {}
        end
      end
      
      def track_json(track)
        {
          id: track.id,
          type: 'track',
          title: track.title,
          duration: track.duration,
          album: { id: track.album.id, title: track.album.title, cover_url: track.album.cover_url },
          artist: { id: track.album.artist.id, name: track.album.artist.name, verified: track.album.artist.verified }
        }
      end
      
      def album_json(album)
        {
          id: album.id,
          type: 'album',
          title: album.title,
          cover_url: album.cover_url,
          tracks_count: album.tracks.count,
          artist: { id: album.artist.id, name: album.artist.name, verified: album.artist.verified }
        }
      end
      
      def video_json(video)
        {
          id: video.id,
          type: 'video',
          title: video.title,
          thumbnail_url: video.thumbnail_url,
          duration: video.duration,
          views_count: video.views_count,
          artist: { id: video.artist.id, name: video.artist.name, verified: video.artist.verified }
        }
      end
      
      def mini_json(mini)
        {
          id: mini.id,
          type: 'mini',
          title: mini.title,
          thumbnail_url: mini.thumbnail_url,
          duration: mini.duration,
          views_count: mini.views_count,
          likes_count: mini.likes_count,
          artist: { id: mini.artist.id, name: mini.artist.name, verified: mini.artist.verified }
        }
      end
      
      def event_json(event)
        {
          id: event.id,
          type: 'event',
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
          type: 'livestream',
          title: livestream.title,
          start_time: livestream.start_time,
          status: livestream.status,
          artist: { id: livestream.artist.id, name: livestream.artist.name, verified: livestream.artist.verified }
        }
      end
    end
  end
end

