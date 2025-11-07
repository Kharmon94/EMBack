module Api
  module V1
    class PlaylistFoldersController < ApplicationController
      before_action :authenticate_user!
      before_action :set_folder, only: [:show, :update, :destroy, :reorder]
      
      # GET /api/v1/playlist_folders
      def index
        folders = current_user.playlist_folders.ordered.includes(:playlists)
        render json: { folders: folders.map { |f| folder_json(f) } }
      end
      
      # POST /api/v1/playlist_folders
      def create
        folder = current_user.playlist_folders.new(folder_params)
        
        if folder.save
          render json: { folder: folder_json(folder) }, status: :created
        else
          render json: { errors: folder.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/playlist_folders/:id
      def update
        if @folder.update(folder_params)
          render json: { folder: folder_json(@folder) }
        else
          render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/playlist_folders/:id
      def destroy
        @folder.destroy
        head :no_content
      end
      
      # POST /api/v1/playlist_folders/:id/reorder
      def reorder
        new_position = params[:position].to_i
        @folder.insert_at(new_position)
        head :no_content
      end
      
      # POST /api/v1/playlist_folders/:id/add_playlist/:playlist_id
      def add_playlist
        folder = current_user.playlist_folders.find(params[:id])
        playlist = current_user.playlists.find(params[:playlist_id])
        
        playlist.update(playlist_folder: folder)
        render json: { success: true }
      end
      
      # DELETE /api/v1/playlist_folders/:id/remove_playlist/:playlist_id
      def remove_playlist
        folder = current_user.playlist_folders.find(params[:id])
        playlist = current_user.playlists.find(params[:playlist_id])
        
        playlist.update(playlist_folder: nil)
        render json: { success: true }
      end
      
      private
      
      def set_folder
        @folder = current_user.playlist_folders.find(params[:id])
      end
      
      def folder_params
        params.require(:playlist_folder).permit(:name, :color_code, :position)
      end
      
      def folder_json(folder)
        {
          id: folder.id,
          name: folder.name,
          color_code: folder.color_code,
          position: folder.position,
          playlist_count: folder.playlist_count,
          created_at: folder.created_at
        }
      end
    end
  end
end

