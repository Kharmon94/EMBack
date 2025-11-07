class AlbumGenre < ApplicationRecord
  belongs_to :album
  belongs_to :genre
  
  validates :album_id, uniqueness: { scope: :genre_id }
end

