class Notification < ApplicationRecord
  belongs_to :user
  
  # Notification types
  TYPES = %w[
    new_album
    new_track
    new_event
    new_livestream
    stream_live
    fan_pass_purchase
    dividend_payment
    token_price_alert
    new_follower
  ].freeze
  
  validates :notification_type, presence: true, inclusion: { in: TYPES }
  validates :title, presence: true
  validates :message, presence: true
  
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :by_type, ->(type) { where(notification_type: type) }
  
  # Mark as read
  def mark_as_read!
    update!(read: true, read_at: Time.current)
  end
  
  # Mark as unread
  def mark_as_unread!
    update!(read: false, read_at: nil)
  end
  
  # Factory methods for creating notifications
  class << self
    def create_album_notification(user, album)
      create!(
        user: user,
        notification_type: 'new_album',
        title: 'New Album Released',
        message: "#{album.artist.name} released a new album: #{album.title}",
        data: { album_id: album.id, artist_id: album.artist_id }
      )
    end
    
    def create_livestream_notification(user, livestream)
      create!(
        user: user,
        notification_type: 'new_livestream',
        title: 'New Livestream Scheduled',
        message: "#{livestream.artist.name} scheduled a livestream: #{livestream.title}",
        data: { livestream_id: livestream.id, artist_id: livestream.artist_id }
      )
    end
    
    def create_live_notification(user, livestream)
      create!(
        user: user,
        notification_type: 'stream_live',
        title: 'Artist is Live!',
        message: "#{livestream.artist.name} is now live: #{livestream.title}",
        data: { livestream_id: livestream.id, artist_id: livestream.artist_id }
      )
    end
    
    def create_event_notification(user, event)
      create!(
        user: user,
        notification_type: 'new_event',
        title: 'New Event Announced',
        message: "#{event.artist.name} announced: #{event.title}",
        data: { event_id: event.id, artist_id: event.artist_id }
      )
    end
    
    def create_follower_notification(user, follower)
      create!(
        user: user,
        notification_type: 'new_follower',
        title: 'New Follower',
        message: "#{follower.username || 'Someone'} started following you",
        data: { follower_id: follower.id }
      )
    end
  end
end

