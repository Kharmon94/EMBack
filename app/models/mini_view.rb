class MiniView < ApplicationRecord
  belongs_to :mini
  belongs_to :user, optional: true  # Allow anonymous views
  
  validates :watched_duration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :completed, -> { where(completed: true) }
  scope :by_nft_holders, -> { where(nft_holder: true) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Mark as completed if watched > 80% of mini
  def check_completion
    return unless mini && watched_duration
    
    completion_threshold = mini.duration * 0.8
    if watched_duration >= completion_threshold
      update(completed: true)
    end
  end
  
  # Calculate engagement score
  def engagement_score
    return 0 unless mini && watched_duration
    
    watch_percentage = (watched_duration.to_f / mini.duration * 100).round(2)
    watch_percentage
  end
end

