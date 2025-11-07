class TrackMood < ApplicationRecord
  belongs_to :track
  belongs_to :mood
  
  validates :track_id, uniqueness: { scope: :mood_id }
end

