class PlaylistFollow < ApplicationRecord
  belongs_to :playlist, counter_cache: :followers_count
  belongs_to :user
  
  validates :user_id, uniqueness: { scope: :playlist_id }
  
  after_create :send_notification
  after_destroy :update_follower_count
  
  private
  
  def send_notification
    # Create notification for playlist owner
    Notification.create(
      user: playlist.user,
      notifiable: playlist,
      notification_type: 'playlist_followed',
      message: "#{user.email} followed your playlist"
    )
  end
  
  def update_follower_count
    playlist.update(followers_count: playlist.playlist_follows.count)
  end
end

