class Follow < ApplicationRecord
  belongs_to :user
  belongs_to :followable, polymorphic: true
  
  # For convenience when following artists (most common case)
  belongs_to :artist, foreign_key: :followable_id, optional: true
  
  validates :user_id, uniqueness: { scope: [:followable_type, :followable_id], message: "already following" }
  
  # Counter cache callbacks
  after_create :increment_counters
  after_destroy :decrement_counters
  
  private
  
  def increment_counters
    # Increment following_count for user
    user.increment!(:following_count) if user.respond_to?(:following_count)
    
    # Increment followers_count for artist (if following an artist)
    if followable_type == 'Artist' && followable.respond_to?(:user)
      followable.user.increment!(:followers_count) if followable.user.respond_to?(:followers_count)
    end
  rescue => e
    Rails.logger.error("Failed to increment follow counters: #{e.message}")
  end
  
  def decrement_counters
    # Decrement following_count for user
    if user.respond_to?(:following_count) && user.following_count > 0
      user.decrement!(:following_count)
    end
    
    # Decrement followers_count for artist
    if followable_type == 'Artist' && followable.respond_to?(:user)
      artist_user = followable.user
      if artist_user.respond_to?(:followers_count) && artist_user.followers_count > 0
        artist_user.decrement!(:followers_count)
      end
    end
  rescue => e
    Rails.logger.error("Failed to decrement follow counters: #{e.message}")
  end
end
