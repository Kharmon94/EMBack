module Api
  module V1
    class MessagesController < BaseController
      before_action :set_conversation
      
      # POST /api/v1/conversations/:conversation_id/messages
      def create
        @message = @conversation.direct_messages.build(message_params)
        @message.user = current_user
        
        if @message.save
          # Broadcast via ActionCable
          ActionCable.server.broadcast(
            "conversation_#{@conversation.id}",
            message_json(@message)
          )
          
          render json: { message: message_json(@message) }, status: :created
        else
          render json: { errors: @message.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/messages/:id/read
      def mark_read
        @message = DirectMessage.find(params[:id])
        
        # Can only mark messages sent to you as read
        unless @message.conversation.users.include?(current_user) && @message.user_id != current_user.id
          render json: { error: 'Unauthorized' }, status: :forbidden
          return
        end
        
        @message.update(read_at: Time.current)
        render json: { message: 'Marked as read' }
      end
      
      private
      
      def set_conversation
        @conversation = Conversation.find(params[:conversation_id])
        
        # Ensure current user is a participant
        unless @conversation.users.include?(current_user)
          render json: { error: 'Not a participant' }, status: :forbidden
        end
      end
      
      def message_params
        params.require(:message).permit(:content, attachments: [])
      end
      
      def message_json(message)
        {
          id: message.id,
          conversation_id: message.conversation_id,
          content: message.content,
          attachments: message.attachments,
          from_me: message.user_id == current_user.id,
          user: {
            id: message.user.id,
            name: message.user.email&.split('@')&.first || "User #{message.user.id}"
          },
          read_at: message.read_at,
          created_at: message.created_at
        }
      end
    end
  end
end

