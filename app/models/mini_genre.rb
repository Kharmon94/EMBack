class MiniGenre < ApplicationRecord
  belongs_to :mini
  belongs_to :genre
  
  validates :mini_id, uniqueness: { scope: :genre_id }
end

