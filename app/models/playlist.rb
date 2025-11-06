class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_tracks, -> { order(position: :asc) }, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  
  validates :title, presence: true
  validates :is_public, inclusion: { in: [true, false] }
  
  scope :public_playlists, -> { where(is_public: true) }
  scope :private_playlists, -> { where(is_public: false) }
  
  # Full-text search
  scope :search, ->(query) {
    return all if query.blank?
    where("search_vector @@ plainto_tsquery('english', ?)", query)
      .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
  }
  
  before_save :update_search_vector
  
  def add_track(track, position = nil)
    position ||= playlist_tracks.maximum(:position).to_i + 1
    playlist_tracks.create(track: track, position: position)
  end
  
  def total_duration
    tracks.sum(:duration)
  end
  
  private
  
  def update_search_vector
    self.search_vector = Arel.sql(
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B')"
    )
  end
end
