class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_tracks, -> { order(position: :asc) }, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  
  validates :title, presence: true
  validates :is_public, inclusion: { in: [true, false] }
  
  scope :public_playlists, -> { where(is_public: true) }
  scope :private_playlists, -> { where(is_public: false) }
  
  def add_track(track, position = nil)
    position ||= playlist_tracks.maximum(:position).to_i + 1
    playlist_tracks.create(track: track, position: position)
  end
  
  def total_duration
    tracks.sum(:duration)
  end
end
