class ListeningHistory < ApplicationRecord
  belongs_to :user
  belongs_to :track
  belongs_to :album, optional: true
  belongs_to :playlist, optional: true
  
  validates :duration_played, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :source, inclusion: { in: %w[album playlist radio search recommendation artist_page direct] }, allow_nil: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :completed_only, -> { where(completed: true) }
  scope :in_timeframe, ->(start_time, end_time) { where(created_at: start_time..end_time) }
  
  before_save :check_completion
  
  private
  
  def check_completion
    if track && duration_played
      # Consider completed if played > 80% of track duration
      self.completed = (duration_played >= track.duration * 0.8)
    end
  end
end

