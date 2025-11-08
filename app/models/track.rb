class Track < ApplicationRecord
  belongs_to :album
  has_one :artist, through: :album
  has_many :streams, dependent: :destroy
  has_many :purchases, as: :purchasable, dependent: :destroy
  has_many :playlist_tracks, dependent: :destroy
  has_many :playlists, through: :playlist_tracks
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  has_many :track_genres, dependent: :destroy
  has_many :genres, through: :track_genres
  has_many :track_moods, dependent: :destroy
  has_many :moods, through: :track_moods
  has_many :pre_saves, as: :pre_saveable, dependent: :destroy
  
  # ACCESS TIERS - Artist can toggle per track
  enum :access_tier, {
    free: 0,           # Full streaming for everyone
    preview_only: 1,   # 30-second preview only
    nft_required: 2    # Only NFT holders can access
  }, prefix: true
  
  # Free streaming quality (for 'free' tier tracks)
  enum :free_quality, {
    standard: 0,  # 128kbps MP3
    high: 1       # 320kbps MP3
  }, prefix: true
  
  validates :title, :duration, :track_number, presence: true
  validates :duration, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :explicit, inclusion: { in: [true, false] }
  validates :access_tier, presence: true
  
  scope :explicit, -> { where(explicit: true) }
  scope :clean, -> { where(explicit: false) }
  
  # Access control scopes
  scope :free_tracks, -> { where(access_tier: :free) }
  scope :preview_tracks, -> { where(access_tier: :preview_only) }
  scope :gated_tracks, -> { where(access_tier: :nft_required) }
  
  # Full-text search with fuzzy matching
  scope :search, ->(query) {
    return all if query.blank?
    
    sanitized = query.strip.gsub(/[^a-zA-Z0-9\s]/, '')
    return none if sanitized.blank?
    
    where("title ILIKE ?", "%#{sanitized}%")
      .order(
        Arel.sql("
          CASE 
            WHEN LOWER(title) = #{connection.quote(sanitized.downcase)} THEN 0
            WHEN title ILIKE #{connection.quote(sanitized + '%')} THEN 1
            WHEN title ILIKE #{connection.quote('%' + sanitized + '%')} THEN 2
            ELSE 3
          END,
          LENGTH(title)
        ")
      )
  }
  
  after_save :update_search_vector, if: :saved_change_to_title?
  
  # Helper methods
  def publicly_accessible?
    free? || preview_only?
  end
  
  def requires_nft?
    access_tier == 'nft_required'
  end
  
  def unique_listeners
    streams.select(:user_id).distinct.count
  end
  
  def total_listen_time
    streams.sum(:duration)
  end
  
  def eligible_streams_count
    streams.where("duration >= ?", 30).count
  end
  
  private
  
  def update_search_vector
    return unless id
    artist_name = album&.artist&.name || ''
    album_title = album&.title || ''
    self.class.connection.execute(
      "UPDATE tracks SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(album_title)}, '')), 'C') " \
      "WHERE id = #{id}"
    )
  end
end
