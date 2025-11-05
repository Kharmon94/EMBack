class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true, counter_cache: true
  
  validates :user_id, uniqueness: { scope: [:likeable_type, :likeable_id], message: "already liked this" }
  
  # After create, increment counter and notify
  after_create :increment_counter, :send_notification
  after_destroy :decrement_counter
  
  private
  
  def increment_counter
    likeable.increment!(:likes_count) if likeable.respond_to?(:likes_count)
  rescue => e
    Rails.logger.error("Failed to increment likes_count: #{e.message}")
  end
  
  def decrement_counter
    likeable.decrement!(:likes_count) if likeable.respond_to?(:likes_count) && likeable.likes_count > 0
  rescue => e
    Rails.logger.error("Failed to decrement likes_count: #{e.message}")
  end
  
  def send_notification
    # Don't notify if user likes their own content
    owner = get_content_owner
    return if owner.nil? || owner.id == user.id
    
    content_name = get_content_name
    
    Notification.create!(
      user: owner,
      notification_type: 'new_like',
      title: 'Someone liked your content',
      message: "Someone liked #{content_name}",
      data: {
        likeable_type: likeable_type,
        likeable_id: likeable_id,
        liker_id: user_id
      }
    )
  rescue => e
    Rails.logger.error("Failed to send like notification: #{e.message}")
  end
  
  def get_content_owner
    case likeable
    when Album
      likeable.artist.user
    when Track
      likeable.album.artist.user
    when Event
      likeable.artist.user
    when Livestream
      likeable.artist.user
    when FanPass
      likeable.artist.user
    when Comment
      likeable.user
    else
      nil
    end
  end
  
  def get_content_name
    case likeable
    when Album, Track, Event, Livestream
      likeable.title
    when FanPass
      likeable.name
    when Comment
      'your comment'
    else
      'your content'
    end
  end
end

