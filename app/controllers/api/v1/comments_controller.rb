module Api
  module V1
    class CommentsController < BaseController
      before_action :set_commentable
      before_action :set_comment, only: [:update, :destroy]
      
      # GET /api/v1/:commentable_type/:commentable_id/comments
      def index
        @comments = @commentable.comments.root_comments.includes(:user, :replies).recent
        @paginated = paginate(@comments)
        
        render json: {
          comments: @paginated.map { |c| comment_json(c) },
          meta: pagination_meta(@comments, @paginated)
        }
      end
      
      # POST /api/v1/:commentable_type/:commentable_id/comments
      def create
        @comment = @commentable.comments.build(comment_params)
        @comment.user = current_user
        
        if @comment.save
          # Send notification to content owner (if not self)
          notify_owner(@comment) if should_notify?(@comment)
          
          render json: {
            comment: comment_json(@comment),
            message: 'Comment posted successfully'
          }, status: :created
        else
          render json: { errors: @comment.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/comments/:id
      def update
        authorize_comment_owner!
        
        if @comment.update(comment_params)
          render json: {
            comment: comment_json(@comment),
            message: 'Comment updated successfully'
          }
        else
          render json: { errors: @comment.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/comments/:id
      def destroy
        authorize_comment_owner!
        
        @comment.destroy
        render json: { message: 'Comment deleted successfully' }
      end
      
      private
      
      def set_commentable
        commentable_type = params[:commentable_type].classify
        commentable_id = params[:commentable_id]
        
        @commentable = commentable_type.constantize.find(commentable_id)
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Content not found' }, status: :not_found
      end
      
      def set_comment
        @comment = Comment.find(params[:id])
      end
      
      def comment_params
        params.require(:comment).permit(:content, :parent_id)
      end
      
      def authorize_comment_owner!
        unless @comment.user_id == current_user.id || current_user.admin?
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end
      
      def should_notify?(comment)
        return false if comment.commentable.nil?
        
        # Get the owner of the content
        owner = case comment.commentable
                when Album
                  comment.commentable.artist.user
                when Track
                  comment.commentable.album.artist.user
                when Event
                  comment.commentable.artist.user
                when Livestream
                  comment.commentable.artist.user
                when FanPass
                  comment.commentable.artist.user
                else
                  nil
                end
        
        owner && owner.id != current_user.id
      end
      
      def notify_owner(comment)
        owner = case comment.commentable
                when Album
                  comment.commentable.artist.user
                when Track
                  comment.commentable.album.artist.user
                when Event
                  comment.commentable.artist.user
                when Livestream
                  comment.commentable.artist.user
                when FanPass
                  comment.commentable.artist.user
                end
        
        return unless owner
        
        content_name = case comment.commentable
                       when Album
                         comment.commentable.title
                       when Track
                         comment.commentable.title
                       when Event
                         comment.commentable.title
                       when Livestream
                         comment.commentable.title
                       when FanPass
                         comment.commentable.name
                       else
                         'your content'
                       end
        
        notification = Notification.create!(
          user: owner,
          notification_type: 'new_comment',
          title: 'New Comment',
          message: "Someone commented on #{content_name}",
          data: {
            comment_id: comment.id,
            commentable_type: comment.commentable_type,
            commentable_id: comment.commentable_id
          }
        )
        
        # Broadcast real-time notification
        NotificationChannel.broadcast_to_user(owner, notification)
      end
      
      def comment_json(comment)
        {
          id: comment.id,
          content: comment.content,
          likes_count: comment.likes_count,
          created_at: comment.created_at,
          user: {
            id: comment.user.id,
            username: comment.user.email.split('@').first,  # Temp username
            wallet_address: comment.user.wallet_address
          },
          replies: comment.replies.map { |r| reply_json(r) }
        }
      end
      
      def reply_json(reply)
        {
          id: reply.id,
          content: reply.content,
          likes_count: reply.likes_count,
          created_at: reply.created_at,
          user: {
            id: reply.user.id,
            username: reply.user.email.split('@').first,
            wallet_address: reply.user.wallet_address
          }
        }
      end
    end
  end
end

