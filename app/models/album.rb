class Album < ApplicationRecord
  belongs_to :artist
  has_many :tracks, dependent: :destroy
  has_many :purchases, as: :purchasable, dependent: :destroy
  has_one :revenue_split, as: :splittable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  has_many :album_genres, dependent: :destroy
  has_many :genres, through: :album_genres
  has_many :pre_saves, as: :pre_saveable, dependent: :destroy
  
  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :released, -> { where("release_date <= ?", Date.today) }
  scope :upcoming, -> { where("release_date > ?", Date.today) }
  
  # Full-text search with fuzzy matching
  scope :search, ->(query) {
    return all if query.blank?
    
    sanitized = query.gsub(/[^a-zA-Z0-9\s]/, '')
    
    where(
      "title ILIKE :partial OR description ILIKE :partial OR search_vector @@ to_tsquery('english', :tsquery)",
      partial: "%#{sanitized}%",
      tsquery: sanitized.split.map { |word| "#{word}:*" }.join(' & ')
    ).order(
      Arel.sql("
        CASE 
          WHEN title ILIKE #{connection.quote(sanitized + '%')} THEN 1
          WHEN title ILIKE #{connection.quote('%' + sanitized + '%')} THEN 2
          ELSE 3
        END,
        ts_rank(search_vector, to_tsquery('english', #{connection.quote(sanitized.split.map { |w| "#{w}:*" }.join(' & '))})) DESC
      ")
    )
  }
  
  after_save :update_search_vector, if: -> { saved_change_to_title? || saved_change_to_description? }
  
  def total_duration
    tracks.sum(:duration)
  end
  
  def total_streams
    tracks.joins(:streams).count
  end
  
  private
  
  def update_search_vector
    return unless id # Skip if not persisted
    artist_name = artist&.name || ''
    self.class.connection.execute(
      "UPDATE albums SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B') " \
      "WHERE id = #{id}"
    )
  end
end
