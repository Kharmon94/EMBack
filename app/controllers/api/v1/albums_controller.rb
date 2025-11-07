module Api
  module V1
    class AlbumsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show], raise: false
      load_and_authorize_resource except: [:create, :index, :show]
      skip_authorization_check only: [:index, :show]
      
      # GET /api/v1/albums
      def index
        @albums = Album.includes(:artist, :tracks)
        
        # Filter by artist
        @albums = @albums.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Filter by release status
        @albums = @albums.released if params[:released] == 'true'
        @albums = @albums.upcoming if params[:upcoming] == 'true'
        
        # Search
        @albums = @albums.where('title ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        
        # ADVANCED FILTERS
        # Genre filter
        @albums = @albums.joins(:album_genres).where(album_genres: { genre_id: params[:genre_ids] }) if params[:genre_ids].present?
        
        # Release date range
        @albums = @albums.where('release_date >= ?', params[:from_date]) if params[:from_date].present?
        @albums = @albums.where('release_date <= ?', params[:to_date]) if params[:to_date].present?
        
        # Price range
        @albums = @albums.where('price >= ?', params[:min_price]) if params[:min_price].present?
        @albums = @albums.where('price <= ?', params[:max_price]) if params[:max_price].present?
        
        # Artist verification
        @albums = @albums.joins(:artist).where(artists: { verified: true }) if params[:verified_only] == 'true'
        
        # Sort
        @albums = case params[:sort]
                  when 'streams' then @albums.left_joins(tracks: :streams).group('albums.id').order('COUNT(streams.id) DESC')
                  when 'recent' then @albums.order(created_at: :desc)
                  when 'release_date' then @albums.order(release_date: :desc)
                  when 'popular' then @albums.left_joins(tracks: :streams).group('albums.id').order('COUNT(streams.id) DESC')
                  else @albums.order(title: :asc)
                  end
        
        @paginated = paginate(@albums)
        
        render json: {
          albums: @paginated.map { |album| album_json(album) },
          meta: pagination_meta(@albums, @paginated)
        }
      end
      
      # GET /api/v1/albums/:id
      def show
        @album = Album.includes(:artist, :tracks).find(params[:id])
        render json: {
          album: detailed_album_json(@album),
          tracks: @album.tracks.order(:track_number).map { |track| track_json(track) }
        }
      end
      
      # POST /api/v1/albums
      def create
        authorize! :create, Album
        
        @album = current_artist.albums.build(album_params)
        
        if @album.save
          # Upload cover to IPFS if file provided
          if params[:cover_file].present?
            ipfs_service = IpfsService.new
            upload_result = ipfs_service.upload_file(
              params[:cover_file].tempfile.path,
              { name: "#{@album.title} Cover", type: 'album_cover' }
            )
            @album.update!(cover_cid: upload_result[:cid], cover_url: upload_result[:url])
          end

          # Create tracks if provided
          if params[:tracks].present?
            ipfs_service = IpfsService.new
            
            params[:tracks].each_with_index do |track_data, index|
              track_attributes = track_data.permit(
                :title, :duration, :track_number, :audio_cid,
                :audio_url, :isrc, :price, :explicit, :access_tier
              ).to_h
              
              # Upload audio file to IPFS if provided
              if track_data[:audio_file].present?
                audio_file = track_data[:audio_file]
                upload_result = ipfs_service.upload_file(
                  audio_file.tempfile.path,
                  { 
                    name: "#{@album.title} - Track #{index + 1} - #{track_attributes[:title]}", 
                    type: 'audio' 
                  }
                )
                track_attributes[:audio_cid] = upload_result[:cid]
                track_attributes[:audio_url] = upload_result[:url]
              end
              
              @album.tracks.create!(track_attributes)
            end
          end
          
          render json: {
            album: detailed_album_json(@album),
            message: 'Album created successfully'
          }, status: :created
        else
          render json: { errors: @album.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/albums/:id
      def update
        if @album.update(album_params)
          render json: { album: detailed_album_json(@album) }
        else
          render json: { errors: @album.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/albums/:id
      def destroy
        @album.destroy
        render json: { message: 'Album deleted successfully' }
      end
      
      # PATCH /api/v1/albums/:id/bulk_update_track_access
      def bulk_update_track_access
        authorize! :update, @album
        
        # Ensure user is the artist who owns this album
        unless current_user.artist && @album.artist_id == current_user.artist.id
          return render json: { error: 'Only the artist can update track access' }, status: :forbidden
        end
        
        track_ids = params[:track_ids] || []
        access_tier = params[:access_tier]
        
        unless ['free', 'preview_only', 'nft_required'].include?(access_tier)
          return render json: { error: 'Invalid access tier' }, status: :bad_request
        end
        
        # Update all specified tracks
        tracks = @album.tracks.where(id: track_ids)
        tracks.update_all(access_tier: Track.access_tiers[access_tier])
        
        render json: {
          updated_count: tracks.count,
          tracks: tracks.reload.map { |t| track_with_access_json(t) },
          message: "#{tracks.count} track(s) updated to #{access_tier}"
        }
      end
      
      private
      
      def album_params
        params.require(:album).permit(
          :title, :description, :cover_cid, :cover_url,
          :price, :upc, :release_date
        )
      end
      
      def album_json(album)
        {
          id: album.id,
          title: album.title,
          description: album.description,
          cover_url: album.cover_url,
          price: album.price,
          release_date: album.release_date,
          tracks_count: album.tracks.count,
          total_duration: album.total_duration,
          artist: {
            id: album.artist.id,
            name: album.artist.name,
            avatar_url: album.artist.avatar_url,
            verified: album.artist.verified
          }
        }
      end
      
      def detailed_album_json(album)
        album_json(album).merge(
          upc: album.upc,
          cover_cid: album.cover_cid,
          total_streams: album.total_streams,
          created_at: album.created_at,
          updated_at: album.updated_at
        )
      end
      
      def track_json(track)
        {
          id: track.id,
          title: track.title,
          duration: track.duration,
          track_number: track.track_number,
          explicit: track.explicit,
          price: track.price,
          streams_count: track.eligible_streams_count,
          access_tier: track.access_tier,
          requires_nft: track.requires_nft?
        }
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
    end
  end
end

