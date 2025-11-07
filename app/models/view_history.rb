class ViewHistory < ApplicationRecord
  belongs_to :user
  belongs_to :viewable, polymorphic: true
  
  validates :duration_watched, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :source, inclusion: { in: %w[feed search recommendation artist_page direct related] }, allow_nil: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :completed_only, -> { where(completed: true) }
  scope :in_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
  
  before_save :calculate_watch_percentage
  before_save :check_completion
  
  private
  
  def calculate_watch_percentage
    if total_duration && total_duration > 0
      self.watch_percentage = ((duration_watched.to_f / total_duration) * 100).round
    end
  end
  
  def check_completion
    # Consider completed if watched > 80%
    self.completed = (watch_percentage && watch_percentage >= 80)
  end
end

