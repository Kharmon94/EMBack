class UserGenrePreference < ApplicationRecord
  belongs_to :user
  belongs_to :genre
  
  validates :user_id, uniqueness: { scope: :genre_id }
  
  scope :top_preferences, -> { order(preference_score: :desc) }
  
  # Calculate preference based on listening history
  def self.calculate_for_user(user)
    # Get genre listening counts
    genre_counts = ListeningHistory.joins(track: :track_genres)
                                   .where(user: user)
                                   .group('genres.id')
                                   .joins('INNER JOIN genres ON genres.id = track_genres.genre_id')
                                   .count
    
    # Update preferences
    genre_counts.each do |genre_id, count|
      preference = find_or_initialize_by(user: user, genre_id: genre_id)
      preference.preference_score = count
      preference.save!
    end
  end
end

