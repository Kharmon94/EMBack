class Stream < ApplicationRecord
  belongs_to :user
  belongs_to :track
  
  validates :duration, presence: true, numericality: { greater_than: 0 }
  
  scope :eligible, -> { where("duration >= ?", 30) }
  scope :recent, -> { order(listened_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_track, ->(track_id) { where(track_id: track_id) }
  
  # Check if stream is eligible for payout (30+ seconds)
  def eligible_for_payout?
    duration >= 30
  end
  
  # Prevent duplicate streams within cooldown period (5 minutes)
  def self.recent_stream_exists?(user_id, track_id, cooldown_minutes = 5)
    where(user_id: user_id, track_id: track_id)
      .where("listened_at > ?", cooldown_minutes.minutes.ago)
      .exists?
  end
end
