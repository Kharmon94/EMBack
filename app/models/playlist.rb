class Playlist < ApplicationRecord
  belongs_to :user
  belongs_to :playlist_folder, optional: true
  has_many :playlist_tracks, -> { order(position: :asc) }, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :playlist_collaborators, dependent: :destroy
  has_many :collaborators, through: :playlist_collaborators, source: :user
  has_many :playlist_follows, dependent: :destroy
  has_many :followers, through: :playlist_follows, source: :user
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  
  validates :title, presence: true
  validates :is_public, inclusion: { in: [true, false] }
  
  scope :public_playlists, -> { where(is_public: true) }
  scope :private_playlists, -> { where(is_public: false) }
  scope :collaborative, -> { where(collaborative: true) }
  scope :community, -> { public_playlists.order(followers_count: :desc) }
  
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
  
  def can_edit?(user)
    return true if self.user_id == user.id
    return false unless collaborative
    playlist_collaborators.where(user: user, role: ['owner', 'editor']).exists?
  end
  
  def can_view?(user)
    return true if is_public
    return true if self.user_id == user.id
    return false unless collaborative
    playlist_collaborators.where(user: user).exists?
  end
  
  private
  
  def update_search_vector
    self.search_vector = Arel.sql(
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B')"
    )
  end
end
