class VideoView < ApplicationRecord
  belongs_to :video
  belongs_to :user, optional: true  # Allow anonymous views
  
  validates :watched_duration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :completed, -> { where(completed: true) }
  scope :by_nft_holders, -> { where(nft_holder: true) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Mark as completed if watched > 80% of video
  def check_completion
    return unless video && watched_duration
    
    completion_threshold = video.duration * 0.8
    if watched_duration >= completion_threshold
      update(completed: true)
    end
  end
end

