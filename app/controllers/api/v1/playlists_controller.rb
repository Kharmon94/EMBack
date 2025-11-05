module Api
  module V1
    class PlaylistsController < BaseController
      load_and_authorize_resource
      
      # GET /api/v1/playlists
      def index
        @playlists = if params[:user_id]
                      Playlist.where(user_id: params[:user_id])
                    else
                      current_user.playlists
                    end
        
        # Include public playlists
        @playlists = @playlists.or(Playlist.public_playlists) if params[:include_public] == 'true'
        
        @playlists = @playlists.order(updated_at: :desc)
        @paginated = paginate(@playlists)
        
        render json: {
          playlists: @paginated.map { |playlist| playlist_json(playlist) },
          meta: pagination_meta(@playlists, @paginated)
        }
      end
      
      # GET /api/v1/playlists/:id
      def show
        render json: {
          playlist: detailed_playlist_json(@playlist),
          tracks: @playlist.tracks.includes(album: :artist).map { |track| track_json(track) }
        }
      end
      
      # POST /api/v1/playlists
      def create
        @playlist = current_user.playlists.build(playlist_params)
        
        if @playlist.save
          render json: {
            playlist: detailed_playlist_json(@playlist),
            message: 'Playlist created successfully'
          }, status: :created
        else
          render json: { errors: @playlist.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/playlists/:id
      def update
        if @playlist.update(playlist_params)
          render json: { playlist: detailed_playlist_json(@playlist) }
        else
          render json: { errors: @playlist.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id
      def destroy
        @playlist.destroy
        render json: { message: 'Playlist deleted successfully' }
      end
      
      # POST /api/v1/playlists/:id/add_track/:track_id
      def add_track
        track = Track.find(params[:track_id])
        
        # Check if track already in playlist
        if @playlist.tracks.include?(track)
          return render json: { error: 'Track already in playlist' }, status: :unprocessable_entity
        end
        
        @playlist.add_track(track)
        
        render json: {
          message: 'Track added to playlist',
          playlist: detailed_playlist_json(@playlist)
        }
      end
      
      # DELETE /api/v1/playlists/:id/remove_track/:track_id
      def remove_track
        playlist_track = @playlist.playlist_tracks.find_by(track_id: params[:track_id])
        
        unless playlist_track
          return render json: { error: 'Track not in playlist' }, status: :not_found
        end
        
        playlist_track.destroy
        
        render json: {
          message: 'Track removed from playlist',
          playlist: detailed_playlist_json(@playlist)
        }
      end
      
      private
      
      def playlist_params
        params.require(:playlist).permit(:title, :description, :is_public)
      end
      
      def playlist_json(playlist)
        {
          id: playlist.id,
          title: playlist.title,
          description: playlist.description,
          is_public: playlist.is_public,
          tracks_count: playlist.tracks.count,
          total_duration: playlist.total_duration,
          updated_at: playlist.updated_at
        }
      end
      
      def detailed_playlist_json(playlist)
        playlist_json(playlist).merge(
          created_at: playlist.created_at,
          user: {
            id: playlist.user.id,
            wallet_address: playlist.user.wallet_address
          }
        )
      end
      
      def track_json(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          track_number: track.track_number,
          album: {
            id: track.album.id,
            title: track.album.title,
            cover_url: track.album.cover_url
          },
          artist: {
            id: track.album.artist.id,
            name: track.album.artist.name
          }
        }
      end
    end
  end
end

