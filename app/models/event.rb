class Event < ApplicationRecord
  belongs_to :artist
  has_many :ticket_tiers, dependent: :destroy
  has_many :tickets, through: :ticket_tiers
  has_one :revenue_split, as: :splittable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  
  enum :status, { draft: 0, published: 1, ongoing: 2, completed: 3, cancelled: 4 }, default: :draft
  
  validates :title, :venue, :start_time, :capacity, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  
  scope :upcoming, -> { where("start_time > ?", Time.current).where(status: [:published, :ongoing]) }
  scope :past, -> { where("end_time < ?", Time.current) }
  scope :active, -> { where(status: [:published, :ongoing]) }
  
  # Full-text search
  scope :search, ->(query) {
    return all if query.blank?
    where("search_vector @@ plainto_tsquery('english', ?)", query)
      .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
  }
  
  before_save :update_search_vector
  
  def sold_tickets_count
    ticket_tiers.sum(:sold)
  end
  
  def available_capacity
    capacity - sold_tickets_count
  end
  
  def is_sold_out?
    available_capacity <= 0
  end
  
  private
  
  def update_search_vector
    artist_name = artist&.name || ''
    self.search_vector = Arel.sql(
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(venue || '')}, '')), 'C') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(location || '')}, '')), 'C') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B')"
    )
  end
end
