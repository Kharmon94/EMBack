module Api
  module V1
    class NotificationsController < BaseController
      skip_before_action :authenticate_user!, only: [], raise: false
      before_action :set_notification, only: [:mark_as_read, :destroy]
      
      # GET /api/v1/notifications
      def index
        @notifications = current_user.notifications.recent
        
        # Filter by read status
        if params[:unread] == 'true'
          @notifications = @notifications.unread
        elsif params[:read] == 'true'
          @notifications = @notifications.read
        end
        
        # Filter by type
        @notifications = @notifications.by_type(params[:type]) if params[:type].present?
        
        @paginated = paginate(@notifications)
        
        render json: {
          notifications: @paginated.map { |n| notification_json(n) },
          unread_count: current_user.notifications.unread.count,
          meta: pagination_meta(@notifications, @paginated)
        }
      end
      
      # POST /api/v1/notifications/:id/mark_as_read
      def mark_as_read
        @notification.mark_as_read!
        
        render json: {
          notification: notification_json(@notification),
          message: 'Notification marked as read'
        }
      end
      
      # POST /api/v1/notifications/mark_all_as_read
      def mark_all_as_read
        current_user.notifications.unread.update_all(
          read: true,
          read_at: Time.current
        )
        
        render json: {
          message: 'All notifications marked as read',
          unread_count: 0
        }
      end
      
      # DELETE /api/v1/notifications/:id
      def destroy
        @notification.destroy
        
        render json: {
          message: 'Notification deleted'
        }
      end
      
      private
      
      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end
      
      def notification_json(notification)
        {
          id: notification.id,
          type: notification.notification_type,
          title: notification.title,
          message: notification.message,
          data: notification.data,
          read: notification.read,
          read_at: notification.read_at,
          created_at: notification.created_at
        }
      end
    end
  end
end

