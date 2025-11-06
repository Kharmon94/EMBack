module Api
  module V1
    class ConversationsController < BaseController
      load_and_authorize_resource
      
      # GET /api/v1/conversations
      def index
        @conversations = current_user.conversations
                                     .includes(:users, :direct_messages, :conversation_participants)
                                     .recent
        
        @conversations = @conversations.joins(:conversation_participants)
                                       .where(conversation_participants: { user_id: current_user.id, archived: false })
        
        @paginated = paginate(@conversations.distinct)
        
        render json: {
          conversations: @paginated.map { |conv| conversation_json(conv) },
          meta: pagination_meta(@conversations, @paginated)
        }
      end
      
      # GET /api/v1/conversations/:id
      def show
        render json: {
          conversation: detailed_conversation_json(@conversation)
        }
      end
      
      # POST /api/v1/conversations
      def create
        recipient_id = params[:recipient_id]
        recipient = ::User.find(recipient_id)
        
        # Check if recipient accepts messages
        unless can_message?(recipient)
          render json: { error: 'This user has disabled messages' }, status: :forbidden
          return
        end
        
        # Check if conversation already exists
        existing = Conversation.between_users(current_user.id, recipient_id)
        if existing
          render json: { conversation: detailed_conversation_json(existing) }
          return
        end
        
        # Create new conversation
        @conversation = Conversation.create!(
          subject: params[:subject],
          order_id: params[:order_id]
        )
        
        # Add participants
        @conversation.conversation_participants.create!(user: current_user)
        @conversation.conversation_participants.create!(user: recipient)
        
        render json: { conversation: detailed_conversation_json(@conversation) }, status: :created
      end
      
      # PATCH /api/v1/conversations/:id/archive
      def archive
        participant = @conversation.conversation_participants.find_by!(user: current_user)
        participant.update!(archived: params[:archived])
        
        render json: { message: params[:archived] ? 'Conversation archived' : 'Conversation unarchived' }
      end
      
      # PATCH /api/v1/conversations/:id/mute
      def mute
        participant = @conversation.conversation_participants.find_by!(user: current_user)
        participant.update!(muted: params[:muted])
        
        render json: { message: params[:muted] ? 'Conversation muted' : 'Conversation unmuted' }
      end
      
      # POST /api/v1/conversations/:id/mark_read
      def mark_read
        participant = @conversation.conversation_participants.find_by!(user: current_user)
        participant.mark_as_read!
        
        render json: { message: 'Marked as read' }
      end
      
      private
      
      def can_message?(recipient)
        return false if recipient.blocked_user_ids.include?(current_user.id)
        
        case recipient.accept_messages
        when 'everyone'
          true
        when 'following_only'
          Follow.exists?(user: recipient, followable: current_user.artist)
        when 'no_one'
          false
        else
          true
        end
      end
      
      def conversation_json(conversation)
        other_user = conversation.other_participant(current_user)
        participant = conversation.conversation_participants.find_by(user: current_user)
        last_message = conversation.direct_messages.recent.last
        
        {
          id: conversation.id,
          subject: conversation.subject,
          other_user: other_user ? {
            id: other_user.id,
            name: other_user.email&.split('@')&.first || "User #{other_user.id}",
            avatar_url: other_user.artist&.avatar_url
          } : nil,
          last_message: last_message ? {
            content: last_message.content,
            created_at: last_message.created_at,
            from_me: last_message.user_id == current_user.id
          } : nil,
          unread_count: conversation.unread_count_for(current_user),
          archived: participant&.archived || false,
          muted: participant&.muted || false,
          updated_at: conversation.last_message_at || conversation.created_at
        }
      end
      
      def detailed_conversation_json(conversation)
        conversation_json(conversation).merge(
          order_id: conversation.order_id,
          messages: conversation.direct_messages.recent.map { |msg| message_json(msg) }
        )
      end
      
      def message_json(message)
        {
          id: message.id,
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

