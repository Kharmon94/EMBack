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
  
  # Full-text search with fuzzy matching
  scope :search, ->(query) {
    return all if query.blank?
    
    sanitized = query.strip.gsub(/[^a-zA-Z0-9\s]/, '')
    return none if sanitized.blank?
    
    where("title ILIKE ? OR description ILIKE ?", "%#{sanitized}%", "%#{sanitized}%")
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
  
  after_save :update_search_vector, if: -> { saved_change_to_title? || saved_change_to_description? }
  
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
    return unless id
    self.class.connection.execute(
      "UPDATE playlists SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') " \
      "WHERE id = #{id}"
    )
  end
end
