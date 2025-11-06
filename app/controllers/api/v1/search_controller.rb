module Api
  module V1
    class SearchController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :all], raise: false
      
      # GET /api/v1/search?q=query&limit=10
      # Quick autocomplete search (limited results per type)
      def index
        query = params[:q]
        limit = (params[:limit] || 10).to_i
        
        if query.blank?
          render json: { results: {}, total_count: 0 }, status: :ok
          return
        end
        
        results = {
          artists: search_artists(query, limit),
          albums: search_albums(query, limit),
          tracks: search_tracks(query, limit),
          videos: search_videos(query, limit),
          minis: search_minis(query, limit),
          events: search_events(query, limit),
          merch: search_merch(query, limit),
          livestreams: search_livestreams(query, limit),
          playlists: search_playlists(query, limit)
        }
        
        total = results.values.sum { |r| r.size }
        
        render json: {
          query: query,
          results: results,
          total_count: total
        }, status: :ok
      end
      
      # GET /api/v1/search/all?q=query&type=artists&page=1
      # Full search results with pagination
      def all
        query = params[:q]
        type = params[:type] || 'all'
        page = (params[:page] || 1).to_i
        per_page = 20
        
        if query.blank?
          render json: { 
            results: [], 
            total_count: 0,
            page: page,
            per_page: per_page,
            total_pages: 0
          }, status: :ok
          return
        end
        
        case type
        when 'artists'
          results = ::Artist.search(query).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |a| format_artist(a) },
            pagination: pagination_meta(results)
          }
        when 'albums'
          results = ::Album.search(query).includes(:artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |a| format_album(a) },
            pagination: pagination_meta(results)
          }
        when 'tracks'
          results = ::Track.search(query).includes(album: :artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |t| format_track(t) },
            pagination: pagination_meta(results)
          }
        when 'videos'
          results = ::Video.search(query).includes(:artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |v| format_video(v) },
            pagination: pagination_meta(results)
          }
        when 'minis'
          results = ::Mini.search(query).includes(:artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |m| format_mini(m) },
            pagination: pagination_meta(results)
          }
        when 'events'
          results = ::Event.search(query).includes(:artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |e| format_event(e) },
            pagination: pagination_meta(results)
          }
        when 'merch'
          results = ::MerchItem.search(query).includes(:artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |m| format_merch(m) },
            pagination: pagination_meta(results)
          }
        when 'livestreams'
          results = ::Livestream.search(query).includes(:artist).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |l| format_livestream(l) },
            pagination: pagination_meta(results)
          }
        when 'playlists'
          results = ::Playlist.search(query).includes(:user).where(is_public: true).page(page).per(per_page)
          render json: {
            query: query,
            type: type,
            results: results.map { |p| format_playlist(p) },
            pagination: pagination_meta(results)
          }
        else # 'all'
          # Return paginated results from all categories
          all_results = []
          
          # Search each category (limit 5 each for overview)
          all_results << { category: 'artists', items: search_artists(query, 5) }
          all_results << { category: 'albums', items: search_albums(query, 5) }
          all_results << { category: 'tracks', items: search_tracks(query, 5) }
          all_results << { category: 'videos', items: search_videos(query, 5) }
          all_results << { category: 'minis', items: search_minis(query, 5) }
          all_results << { category: 'events', items: search_events(query, 5) }
          all_results << { category: 'merch', items: search_merch(query, 5) }
          all_results << { category: 'livestreams', items: search_livestreams(query, 5) }
          all_results << { category: 'playlists', items: search_playlists(query, 5) }
          
          total = all_results.sum { |r| r[:items].size }
          
          render json: {
            query: query,
            type: 'all',
            results: all_results,
            total_count: total
          }
        end
      end
      
      private
      
      def search_artists(query, limit)
        ::Artist.search(query).limit(limit).map { |a| format_artist(a) }
      end
      
      def search_albums(query, limit)
        ::Album.search(query).includes(:artist).limit(limit).map { |a| format_album(a) }
      end
      
      def search_tracks(query, limit)
        ::Track.search(query).includes(album: :artist).limit(limit).map { |t| format_track(t) }
      end
      
      def search_videos(query, limit)
        ::Video.search(query).includes(:artist).limit(limit).map { |v| format_video(v) }
      end
      
      def search_minis(query, limit)
        ::Mini.search(query).includes(:artist).limit(limit).map { |m| format_mini(m) }
      end
      
      def search_events(query, limit)
        ::Event.search(query).includes(:artist).limit(limit).map { |e| format_event(e) }
      end
      
      def search_merch(query, limit)
        ::MerchItem.search(query).includes(:artist).limit(limit).map { |m| format_merch(m) }
      end
      
      def search_livestreams(query, limit)
        ::Livestream.search(query).includes(:artist).limit(limit).map { |l| format_livestream(l) }
      end
      
      def search_playlists(query, limit)
        ::Playlist.search(query).includes(:user).where(is_public: true).limit(limit).map { |p| format_playlist(p) }
      end
      
      # Formatters
      def format_artist(artist)
        {
          id: artist.id,
          name: artist.name,
          avatar_url: artist.avatar_url,
          verified: artist.verified,
          bio: artist.bio&.truncate(100)
        }
      end
      
      def format_album(album)
        {
          id: album.id,
          title: album.title,
          artist_id: album.artist_id,
          artist_name: album.artist&.name,
          cover_url: album.cover_url,
          release_date: album.release_date
        }
      end
      
      def format_track(track)
        {
          id: track.id,
          title: track.title,
          album_id: track.album_id,
          album_title: track.album&.title,
          artist_id: track.album&.artist_id,
          artist_name: track.album&.artist&.name,
          duration: track.duration,
          access_tier: track.access_tier
        }
      end
      
      def format_video(video)
        {
          id: video.id,
          title: video.title,
          artist_id: video.artist_id,
          artist_name: video.artist&.name,
          thumbnail_url: video.thumbnail_url,
          views_count: video.views_count,
          duration: video.duration,
          access_tier: video.access_tier
        }
      end
      
      def format_mini(mini)
        {
          id: mini.id,
          title: mini.title,
          artist_id: mini.artist_id,
          artist_name: mini.artist&.name,
          thumbnail_url: mini.thumbnail_url,
          views_count: mini.views_count,
          likes_count: mini.likes_count,
          access_tier: mini.access_tier
        }
      end
      
      def format_event(event)
        {
          id: event.id,
          title: event.title,
          artist_id: event.artist_id,
          artist_name: event.artist&.name,
          venue: event.venue,
          location: event.location,
          start_time: event.start_time,
          image_url: event.image_url,
          status: event.status
        }
      end
      
      def format_merch(merch)
        {
          id: merch.id,
          title: merch.title,
          artist_id: merch.artist_id,
          artist_name: merch.artist&.name,
          price: merch.price,
          images: merch.images,
          in_stock: merch.in_stock?,
          rating_average: merch.rating_average
        }
      end
      
      def format_livestream(livestream)
        {
          id: livestream.id,
          title: livestream.title,
          artist_id: livestream.artist_id,
          artist_name: livestream.artist&.name,
          status: livestream.status,
          start_time: livestream.start_time,
          thumbnail_url: livestream.thumbnail_url,
          viewer_count: livestream.viewer_count
        }
      end
      
      def format_playlist(playlist)
        {
          id: playlist.id,
          title: playlist.title,
          user_id: playlist.user_id,
          username: playlist.user&.email,
          track_count: playlist.tracks.count,
          is_public: playlist.is_public
        }
      end
      
      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end

