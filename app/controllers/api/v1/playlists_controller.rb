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
      
      # GET /api/v1/playlists/discover
      def discover
        # Genre-based playlists
        genre_playlists = Playlist.public_playlists
                                 .joins(:playlist_tracks)
                                 .group('playlists.id')
                                 .order(followers_count: :desc)
                                 .limit(20)
        
        # Curator playlists
        curator_playlists = Playlist.public_playlists
                                   .joins(user: :curator_profile)
                                   .where(curator_profiles: { verified: true })
                                   .order('curator_profiles.followers_count DESC')
                                   .limit(10)
        
        render json: {
          genre_playlists: genre_playlists.map { |p| playlist_json(p) },
          curator_playlists: curator_playlists.map { |p| curator_playlist_json(p) }
        }
      end
      
      # GET /api/v1/playlists/collaborative
      def collaborative
        playlists = current_user.collaborative_playlists.order(updated_at: :desc)
        
        render json: {
          playlists: playlists.map { |p| collaborative_playlist_json(p) }
        }
      end
      
      # GET /api/v1/playlists/community
      def community
        playlists = Playlist.community.limit(30)
        
        render json: {
          playlists: playlists.map { |p| playlist_json(p) }
        }
      end
      
      # POST /api/v1/playlists/:id/collaborators
      def add_collaborator
        user_to_add = User.find(params[:user_id])
        role = params[:role] || 'editor'
        
        collaborator = @playlist.playlist_collaborators.build(user: user_to_add, role: role)
        
        if collaborator.save
          render json: {
            message: 'Collaborator added',
            collaborator: collaborator_json(collaborator)
          }
        else
          render json: { errors: collaborator.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id/collaborators/:user_id
      def remove_collaborator
        collaborator = @playlist.playlist_collaborators.find_by(user_id: params[:user_id])
        
        unless collaborator
          return render json: { error: 'Collaborator not found' }, status: :not_found
        end
        
        collaborator.destroy
        render json: { message: 'Collaborator removed' }
      end
      
      # POST /api/v1/playlists/:id/follow
      def follow
        follow = @playlist.playlist_follows.build(user: current_user)
        
        if follow.save
          render json: { message: 'Playlist followed', followers_count: @playlist.followers_count }
        else
          render json: { error: 'Already following' }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id/follow
      def unfollow
        follow = @playlist.playlist_follows.find_by(user: current_user)
        
        unless follow
          return render json: { error: 'Not following this playlist' }, status: :not_found
        end
        
        follow.destroy
        render json: { message: 'Playlist unfollowed', followers_count: @playlist.followers_count }
      end
      
      private
      
      def playlist_params
        params.require(:playlist).permit(:title, :description, :is_public, :collaborative)
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
          collaborative: playlist.collaborative,
          followers_count: playlist.followers_count,
          user: {
            id: playlist.user.id,
            wallet_address: playlist.user.wallet_address
          }
        )
      end
      
      def collaborative_playlist_json(playlist)
        detailed_playlist_json(playlist).merge(
          collaborators: playlist.playlist_collaborators.includes(:user).map { |c| collaborator_json(c) },
          my_role: playlist.playlist_collaborators.find_by(user: current_user)&.role
        )
      end
      
      def curator_playlist_json(playlist)
        playlist_json(playlist).merge(
          curator: {
            id: playlist.user.curator_profile.id,
            display_name: playlist.user.curator_profile.display_name,
            verified: playlist.user.curator_profile.verified
          }
        )
      end
      
      def collaborator_json(collaborator)
        {
          id: collaborator.id,
          user_id: collaborator.user.id,
          email: collaborator.user.email,
          role: collaborator.role,
          added_at: collaborator.created_at
        }
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

