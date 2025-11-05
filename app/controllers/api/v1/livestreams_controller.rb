module Api
  module V1
    class LivestreamsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show, :messages, :status]
      load_and_authorize_resource except: [:start, :stop, :status, :index, :show, :messages]
      skip_authorization_check only: [:index, :show, :messages, :status]
      
      # GET /api/v1/livestreams
      def index
        @livestreams = Livestream.includes(:artist)
        
        # Filter by status
        @livestreams = @livestreams.active if params[:active] == 'true'
        @livestreams = @livestreams.upcoming if params[:upcoming] == 'true'
        
        # Filter by artist
        @livestreams = @livestreams.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Order
        @livestreams = @livestreams.order(start_time: :desc)
        
        @paginated = paginate(@livestreams)
        
        render json: {
          livestreams: @paginated.map { |ls| livestream_json(ls) },
          meta: pagination_meta(@livestreams, @paginated)
        }
      end
      
      # GET /api/v1/livestreams/:id
      def show
        # Check token-gated access
        if @livestream.is_token_gated?
          artist_token = @livestream.artist.artist_token
          
          if current_user && artist_token
            # Check if user has enough tokens
            # TODO: Verify on-chain token balance
            user_balance = 0 # Placeholder
            
            if user_balance < @livestream.token_gate_amount
              return render json: {
                error: 'Insufficient tokens for access',
                required: @livestream.token_gate_amount,
                balance: user_balance,
                token: {
                  name: artist_token.name,
                  symbol: artist_token.symbol,
                  mint_address: artist_token.mint_address
                }
              }, status: :forbidden
            end
          elsif !current_user
            return render json: {
              error: 'Authentication required for token-gated stream'
            }, status: :unauthorized
          end
        end
        
        render json: {
          livestream: detailed_livestream_json(@livestream),
          access_granted: true
        }
      end
      
      # POST /api/v1/livestreams
      def create
        @livestream = current_artist.livestreams.build(livestream_params)
        
        if @livestream.save
          service = StreamingRtmpService.new(@livestream)
          credentials = service.credentials
          
          render json: {
            livestream: detailed_livestream_json(@livestream),
            rtmp_credentials: credentials,
            message: 'Livestream created successfully. Use the RTMP credentials in OBS.'
          }, status: :created
        else
          render json: { errors: @livestream.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/livestreams/:id/start
      def start
        unless @livestream.artist.user_id == current_user.id
          return render json: { error: 'Only the artist can start their livestream' }, status: :forbidden
        end
        
        if @livestream.live?
          return render json: { error: 'Livestream already live' }, status: :unprocessable_entity
        end
        
        @livestream.start_stream!
        
        render json: {
          livestream: detailed_livestream_json(@livestream),
          message: 'Livestream started - you can now begin streaming in OBS'
        }
      end
      
      # POST /api/v1/livestreams/:id/stop  
      def stop
        unless @livestream.artist.user_id == current_user.id
          return render json: { error: 'Only the artist can stop their livestream' }, status: :forbidden
        end
        
        unless @livestream.live?
          return render json: { error: 'Livestream is not live' }, status: :unprocessable_entity
        end
        
        @livestream.end_stream!
        
        render json: {
          livestream: livestream_json(@livestream),
          message: 'Livestream ended',
          stats: {
            duration: @livestream.stream_duration,
            peak_viewers: @livestream.viewer_count,
            total_tips: @livestream.stream_messages.where.not(tip_amount: nil).sum(:tip_amount)
          }
        }
      end
      
      # GET /api/v1/livestreams/:id/status
      def status
        service = StreamingRtmpService.new(@livestream)
        
        render json: {
          status: service.status,
          is_live: @livestream.is_live?,
          hls_url: @livestream.is_live? ? @livestream.hls_url : nil
        }
      end
      
      # POST /api/v1/livestreams/:id/tip
      def tip
        authorize! :create, StreamMessage
        
        amount = params[:amount].to_f
        mint = params[:mint]
        signature = params[:transaction_signature]
        
        unless amount > 0 && mint.present? && signature.present?
          return render json: { error: 'Invalid tip parameters' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        
        message = @livestream.stream_messages.create!(
          user: current_user,
          content: "Tipped #{amount} tokens",
          tip_amount: amount,
          tip_mint: mint,
          sent_at: Time.current
        )
        
        # Broadcast tip to all viewers
        ActionCable.server.broadcast(
          "livestream:#{@livestream.id}",
          {
            type: 'tip',
            message: {
              id: message.id,
              user: {
                wallet_address: current_user.wallet_address
              },
              amount: amount,
              mint: mint,
              sent_at: message.sent_at.iso8601
            }
          }
        )
        
        render json: {
          message: 'Tip sent successfully',
          tip: {
            amount: amount,
            mint: mint
          }
        }
      end
      
      # GET /api/v1/livestreams/:id/messages
      def messages
        @messages = @livestream.stream_messages.includes(:user).order(sent_at: :desc).limit(100)
        
        render json: {
          messages: @messages.map { |msg| message_json(msg) }
        }
      end
      
      private
      
      def livestream_params
        params.require(:livestream).permit(
          :title, :description, :start_time, :token_gate_amount
        )
      end
      
      def livestream_json(livestream)
        {
          id: livestream.id,
          title: livestream.title,
          description: livestream.description,
          status: livestream.status,
          start_time: livestream.start_time,
          end_time: livestream.end_time,
          viewer_count: livestream.viewer_count,
          token_gate_amount: livestream.token_gate_amount,
          is_token_gated: livestream.is_token_gated?,
          artist: {
            id: livestream.artist.id,
            name: livestream.artist.name,
            avatar_url: livestream.artist.avatar_url,
            verified: livestream.artist.verified
          }
        }
      end
      
      def detailed_livestream_json(livestream)
        base = livestream_json(livestream).merge(
          messages_count: livestream.stream_messages.count,
          total_tips: livestream.stream_messages.where.not(tip_amount: nil).sum(:tip_amount),
          created_at: livestream.created_at,
          started_at: livestream.started_at,
          ended_at: livestream.ended_at,
          duration: livestream.stream_duration
        )
        
        # Include HLS URL if live
        if livestream.is_live?
          base[:hls_url] = livestream.hls_url
        end
        
        # Include RTMP credentials if user is the artist
        if current_user && livestream.artist.user_id == current_user.id
          base[:rtmp_credentials] = {
            rtmp_url: livestream.rtmp_url,
            stream_key: livestream.stream_key,
            full_url: "#{livestream.rtmp_url}/#{livestream.stream_key}"
          }
        end
        
        base
      end
      
      def message_json(message)
        {
          id: message.id,
          content: message.content,
          tip_amount: message.tip_amount,
          tip_mint: message.tip_mint,
          sent_at: message.sent_at,
          user: {
            wallet_address: message.user.wallet_address
          }
        }
      end
    end
  end
end

