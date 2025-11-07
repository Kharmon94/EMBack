class PlaylistFolder < ApplicationRecord
  belongs_to :user
  has_many :playlists, dependent: :nullify
  
  validates :name, presence: true
  
  scope :ordered, -> { order(:position) }
  
  def playlist_count
    playlists.count
  end
end

