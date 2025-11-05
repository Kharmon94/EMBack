module Api
  module V1
    class StreamingController < BaseController
      skip_before_action :authenticate_user!
      skip_authorization_check
      
      # POST /api/v1/streaming/validate
      def validate
        stream_key = params[:stream_key]
        
        result = StreamingRtmpService.validate_stream_key(stream_key)
        
        render json: result
      end
      
      # POST /api/v1/streaming/stream_started
      def stream_started
        stream_key = params[:stream_key]
        
        success = StreamingRtmpService.on_stream_start(stream_key)
        
        render json: { success: success }
      end
      
      # POST /api/v1/streaming/stream_ended
      def stream_ended
        stream_key = params[:stream_key]
        
        success = StreamingRtmpService.on_stream_end(stream_key)
        
        render json: { success: success }
      end
    end
  end
end

