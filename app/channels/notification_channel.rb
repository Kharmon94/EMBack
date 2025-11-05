class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user if current_user
  end

  def unsubscribed
    stop_all_streams
  end
  
  # Broadcast notification to user
  def self.broadcast_to_user(user, notification)
    broadcast_to(
      user,
      {
        type: 'notification',
        notification: {
          id: notification.id,
          type: notification.notification_type,
          title: notification.title,
          message: notification.message,
          data: notification.data,
          read: notification.read,
          created_at: notification.created_at
        }
      }
    )
  end
end

