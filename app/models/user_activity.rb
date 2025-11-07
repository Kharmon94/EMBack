class UserActivity < ApplicationRecord
  belongs_to :user
  belongs_to :activityable, polymorphic: true
  
  validates :activity_type, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :for_user, ->(user) { where(user: user) }
  scope :feed_for_user, ->(user) {
    # Get activities from user's followed artists and friends
    followed_ids = user.follows.where(followable_type: ['Artist', 'User']).pluck(:followable_id)
    where(user_id: followed_ids).recent
  }
  
  # Create activity for various actions
  def self.track_like(user, likeable)
    create(user: user, activityable: likeable, activity_type: 'liked')
  end
  
  def self.track_comment(user, commentable)
    create(user: user, activityable: commentable, activity_type: 'commented')
  end
  
  def self.track_share(user, shareable)
    create(user: user, activityable: shareable, activity_type: 'shared')
  end
  
  def self.track_follow(user, followable)
    create(user: user, activityable: followable, activity_type: 'followed')
  end
  
  def self.track_stream(user, track)
    create(user: user, activityable: track, activity_type: 'streamed')
  end
  
  def self.track_purchase(user, purchasable)
    create(user: user, activityable: purchasable, activity_type: 'purchased')
  end
end

