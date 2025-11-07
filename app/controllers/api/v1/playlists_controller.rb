module Api
  module V1
    class PlaylistsController < ApplicationController
      before_action :authenticate_user!, except: [:index, :show, :discover, :community]
      before_action :set_playlist, only: [:show, :update, :destroy, :add_track, :remove_track, 
                                           :add_collaborator, :remove_collaborator, :follow, :unfollow,
                                           :upload_artwork, :remove_artwork]
      load_and_authorize_resource except: [:index, :discover, :community, :collaborative]
      
      # GET /api/v1/playlists
      def index
        if current_user
          playlists = current_user.playlists.includes(:tracks, :user, :playlist_folder)
          render json: { playlists: playlists.map { |p| playlist_json(p) } }
        else
          render json: { playlists: [] }
        end
      end
      
      # GET /api/v1/playlists/:id
      def show
        authorize! :read, @playlist
        render json: { playlist: playlist_detail_json(@playlist) }
      end
      
      # POST /api/v1/playlists
      def create
        playlist = current_user.playlists.new(playlist_params)
        
        if playlist.save
          render json: { playlist: playlist_json(playlist) }, status: :created
        else
          render json: { errors: playlist.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/playlists/:id
      def update
        if @playlist.update(playlist_params)
          render json: { playlist: playlist_json(@playlist) }
        else
          render json: { errors: @playlist.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id
      def destroy
        @playlist.destroy
        head :no_content
      end
      
      # POST /api/v1/playlists/:id/add_track/:track_id
      def add_track
        track = Track.find(params[:track_id])
        
        # Get the highest position
        max_position = @playlist.playlist_tracks.maximum(:position) || -1
        
        playlist_track = @playlist.playlist_tracks.create(
          track: track,
          position: max_position + 1
        )
        
        if playlist_track.persisted?
          render json: { success: true, playlist: playlist_json(@playlist) }
        else
          render json: { errors: playlist_track.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id/remove_track/:track_id
      def remove_track
        playlist_track = @playlist.playlist_tracks.find_by(track_id: params[:track_id])
        
        if playlist_track
          playlist_track.destroy
          render json: { success: true, playlist: playlist_json(@playlist) }
        else
          render json: { error: 'Track not found in playlist' }, status: :not_found
        end
      end
      
      # GET /api/v1/playlists/discover
      def discover
        # Featured playlists
        featured = Playlist.where(is_public: true).order('RANDOM()').limit(10)
        render json: { playlists: featured.map { |p| playlist_json(p) } }
      end
      
      # GET /api/v1/playlists/collaborative
      def collaborative
        return render json: { playlists: [] } unless current_user
        
        playlists = current_user.collaborative_playlists.includes(:tracks, :user)
        render json: { playlists: playlists.map { |p| collaborative_playlist_json(p) } }
      end
      
      # GET /api/v1/playlists/community
      def community
        playlists = Playlist.community.includes(:tracks, :user).limit(20)
        render json: { playlists: playlists.map { |p| playlist_json(p) } }
      end
      
      # POST /api/v1/playlists/:id/collaborators
      def add_collaborator
        user = User.find(params[:user_id])
        role = params[:role] || 'editor'
        
        collaborator = @playlist.playlist_collaborators.create(
          user: user,
          role: role
        )
        
        if collaborator.persisted?
          render json: { success: true, collaborator: collaborator_json(collaborator) }
        else
          render json: { errors: collaborator.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id/collaborators/:user_id
      def remove_collaborator
        collaborator = @playlist.playlist_collaborators.find_by(user_id: params[:user_id])
        
        if collaborator
          collaborator.destroy
          render json: { success: true }
        else
          render json: { error: 'Collaborator not found' }, status: :not_found
        end
      end
      
      # POST /api/v1/playlists/:id/follow
      def follow
        follow = current_user.playlist_follows.create(playlist: @playlist)
        
        if follow.persisted?
          render json: { success: true, followers_count: @playlist.followers.count }
        else
          render json: { errors: follow.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id/follow
      def unfollow
        follow = current_user.playlist_follows.find_by(playlist: @playlist)
        
        if follow
          follow.destroy
          render json: { success: true, followers_count: @playlist.followers.count }
        else
          render json: { error: 'Not following this playlist' }, status: :not_found
        end
      end
      
      # POST /api/v1/playlists/:id/upload_artwork
      def upload_artwork
        if params[:artwork].blank?
          return render json: { error: 'No artwork provided' }, status: :unprocessable_entity
        end
        
        # In a real app, upload to S3/IPFS and get URL
        # For now, we'll simulate it
        artwork_url = "https://placeholder.example.com/playlist_#{@playlist.id}.jpg"
        
        if @playlist.update(custom_cover_url: artwork_url)
          render json: { custom_cover_url: artwork_url }
        else
          render json: { errors: @playlist.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlists/:id/remove_artwork
      def remove_artwork
        if @playlist.update(custom_cover_url: nil)
          render json: { success: true }
        else
          render json: { errors: @playlist.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_playlist
        @playlist = Playlist.find(params[:id])
      end
      
      def playlist_params
        params.require(:playlist).permit(:title, :description, :is_public, :collaborative, 
                                         :custom_cover_url, :playlist_folder_id)
      end
      
      def playlist_json(playlist)
        {
          id: playlist.id,
          title: playlist.title,
          description: playlist.description,
          is_public: playlist.is_public,
          collaborative: playlist.collaborative,
          custom_cover_url: playlist.custom_cover_url,
          track_count: playlist.tracks.count,
          user: {
            id: playlist.user.id,
            email: playlist.user.email
          },
          playlist_folder_id: playlist.playlist_folder_id,
          created_at: playlist.created_at
        }
      end
      
      def playlist_detail_json(playlist)
        playlist_json(playlist).merge(
          tracks: playlist.playlist_tracks.includes(:track).map { |pt| track_json(pt.track) },
          collaborators: playlist.playlist_collaborators.map { |c| collaborator_json(c) },
          followers_count: playlist.followers.count,
          is_following: current_user ? current_user.playlist_follows.exists?(playlist: playlist) : false
        )
      end
      
      def track_json(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          audio_url: track.audio_url,
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
      
      def collaborative_playlist_json(playlist)
        playlist_json(playlist).merge(
          role: playlist.playlist_collaborators.find_by(user: current_user)&.role
        )
      end
      
      def collaborator_json(collaborator)
        {
          id: collaborator.id,
          user_id: collaborator.user_id,
          role: collaborator.role,
          user: {
            id: collaborator.user.id,
            email: collaborator.user.email
          }
        }
      end
    end
  end
end
