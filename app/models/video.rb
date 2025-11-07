class Video < ApplicationRecord
  belongs_to :artist
  
  # Full-text search
  scope :search, ->(query) {
    return all if query.blank?
    where("search_vector @@ plainto_tsquery('english', ?)", query)
      .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
  }
  
  before_save :update_search_vector
  
  private
  
  def update_search_vector
    artist_name = artist&.name || ''
    self.search_vector = Arel.sql(
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B')"
    )
  end
  
  public
  has_many :video_views, dependent: :destroy
  has_many :purchases, as: :purchasable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  
  # Access tiers (same as tracks)
  enum :access_tier, {
    free: 0,           # Full video for everyone
    preview_only: 1,   # Preview duration, then purchase
    nft_required: 2,   # Only NFT/fan pass holders
    paid: 3            # Pay-per-view purchase
  }, prefix: true
  
  validates :title, presence: true
  validates :duration, numericality: { greater_than: 0 }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :preview_duration, numericality: { greater_than: 0, less_than_or_equal_to: 300 }
  
  scope :published, -> { where(published: true) }
  scope :recent, -> { published.order(published_at: :desc) }
  scope :popular, -> { published.order(views_count: :desc) }
  scope :trending, -> { published.where('published_at > ?', 7.days.ago).order(views_count: :desc) }
  
  def publish!
    update!(published: true, published_at: Time.current)
  end
  
  def unpublish!
    update!(published: false)
  end
  
  def increment_views!
    increment!(:views_count)
  end
  
  def requires_purchase?(user)
    return false if free?
    return false if user && owns_nft?(user)
    
    paid? || (preview_only? && !user_purchased?(user))
  end
  
  def user_purchased?(user)
    return false unless user
    purchases.exists?(user: user)
  end
  
  def owns_nft?(user)
    return false unless user
    # Check if user owns artist's fan pass or album NFT
    artist.fan_passes.joins(:fan_pass_nfts).exists?(fan_pass_nfts: { user: user, status: :active })
  end
  
  def allowed_duration(user)
    return duration if free?
    return duration if user && (owns_nft?(user) || user_purchased?(user))
    return preview_duration if preview_only?
    return 0 if nft_required? || paid?
    duration
  end
end

