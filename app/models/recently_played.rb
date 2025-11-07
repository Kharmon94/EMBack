class RecentlyPlayed < ApplicationRecord
  belongs_to :user
  belongs_to :playable, polymorphic: true
  
  validates :user_id, uniqueness: { scope: [:playable_type, :playable_id] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :tracks_only, -> { where(playable_type: 'Track') }
  scope :albums_only, -> { where(playable_type: 'Album') }
  scope :videos_only, -> { where(playable_type: 'Video') }
  
  # Add or update recently played
  def self.track_play(user, playable)
    # Find existing or create new
    recently_played = find_or_initialize_by(
      user: user,
      playable: playable
    )
    
    # Update timestamp to move to top of list
    recently_played.touch
    recently_played.save!
    
    # Keep only last 50 per user
    cleanup_old_entries(user)
    
    recently_played
  end
  
  def self.cleanup_old_entries(user, keep_count = 50)
    user_entries = where(user: user).order(created_at: :desc)
    
    if user_entries.count > keep_count
      ids_to_keep = user_entries.limit(keep_count).pluck(:id)
      where(user: user).where.not(id: ids_to_keep).delete_all
    end
  end
end

