class Track < ApplicationRecord
  belongs_to :album
  has_one :artist, through: :album
  has_many :streams, dependent: :destroy
  has_many :purchases, as: :purchasable, dependent: :destroy
  has_many :playlist_tracks, dependent: :destroy
  has_many :playlists, through: :playlist_tracks
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  
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
  
  # Helper methods
  def publicly_accessible?
    free? || preview_only?
  end
  
  def requires_nft?
    nft_required?
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
end
