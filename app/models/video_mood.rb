class VideoMood < ApplicationRecord
  belongs_to :video
  belongs_to :mood
  
  validates :video_id, uniqueness: { scope: :mood_id }
end

