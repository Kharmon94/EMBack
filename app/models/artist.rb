class Artist < ApplicationRecord
  belongs_to :user
  
  # Associations
  # NOTE: Each artist can only have ONE token (enforced via has_one relationship)
  # Combined with User.has_one(:artist), this ensures one token per wallet
  has_one :artist_token, dependent: :destroy
  has_many :albums, dependent: :destroy
  has_many :tracks, through: :albums
  has_many :videos, dependent: :destroy
  has_many :minis, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :livestreams, dependent: :destroy
  has_many :merch_items, dependent: :destroy
  has_many :fan_passes, dependent: :destroy
  has_many :airdrops, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :verified, inclusion: { in: [true, false] }
  
  # Scopes
  scope :verified, -> { where(verified: true) }
  scope :with_token, -> { joins(:artist_token) }
  
  # Full-text search with fuzzy matching
  scope :search, ->(query) {
    return all if query.blank?
    
    # Combine partial ILIKE matching with full-text search for better fuzzy results
    sanitized = query.gsub(/[^a-zA-Z0-9\s]/, '')
    
    where(
      "name ILIKE :partial OR bio ILIKE :partial OR search_vector @@ to_tsquery('english', :tsquery)",
      partial: "%#{sanitized}%",
      tsquery: sanitized.split.map { |word| "#{word}:*" }.join(' & ')
    ).order(
      Arel.sql("
        CASE 
          WHEN name ILIKE #{connection.quote(sanitized + '%')} THEN 1
          WHEN name ILIKE #{connection.quote('%' + sanitized + '%')} THEN 2
          ELSE 3
        END,
        ts_rank(search_vector, to_tsquery('english', #{connection.quote(sanitized.split.map { |w| "#{w}:*" }.join(' & '))})) DESC
      ")
    )
  }
  
  after_save :update_search_vector
  
  private
  
  def update_search_vector
    # Use execute to run raw SQL instead of assigning to the column
    self.class.connection.execute(
      "UPDATE artists SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(name || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(bio || '')}, '')), 'B') " \
      "WHERE id = #{id}"
    )
  end
end
