class Mini < ApplicationRecord
  belongs_to :artist
  has_many :mini_views, dependent: :destroy
  has_many :purchases, as: :purchasable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  has_many :mini_genres, dependent: :destroy
  has_many :genres, through: :mini_genres
  
  # Access tiers (same as tracks/videos)
  enum :access_tier, {
    free: 0,           # Full mini for everyone
    preview_only: 1,   # Preview duration, then purchase
    nft_required: 2,   # Only NFT/fan pass holders
    paid: 3            # Pay-per-view purchase
  }, prefix: true
  
  validates :title, presence: true
  validates :duration, numericality: { greater_than: 0, less_than_or_equal_to: 120 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :preview_duration, numericality: { greater_than: 0, less_than_or_equal_to: 60 }
  
  scope :published, -> { where(published: true) }
  scope :recent, -> { published.order(published_at: :desc) }
  scope :popular, -> { published.order(views_count: :desc) }
  
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
  
  # Trending: high engagement in last 24-48 hours
  scope :trending, -> {
    published
      .where('published_at > ?', 48.hours.ago)
      .order(Arel.sql('(views_count + likes_count * 2 + shares_count * 5) DESC'))
      .limit(50)
  }
  
  # For You feed: personalized discovery algorithm
  scope :for_you, ->(user = nil) {
    query = published.where('published_at > ?', 7.days.ago)
    
    if user
      # Boost from followed artists
      followed_artist_ids = user.follows.where(followable_type: 'Artist').pluck(:followable_id)
      
      if followed_artist_ids.any?
        # Prioritize followed artists, then engagement
        query = query.order(
          Arel.sql("CASE WHEN artist_id IN (#{followed_artist_ids.join(',')}) THEN 1 ELSE 2 END"),
          Arel.sql('(views_count * 0.3 + likes_count * 0.5 + shares_count * 0.2) DESC')
        )
      else
        # No follows yet, show popular content
        query = query.order(Arel.sql('(views_count + likes_count * 2 + shares_count * 5) DESC'))
      end
    else
      # Guest users get popular content
      query = query.order(Arel.sql('(views_count + likes_count * 2 + shares_count * 5) DESC'))
    end
    
    query.limit(100)
  }
  
  def publish!
    update!(published: true, published_at: Time.current)
  end
  
  def unpublish!
    update!(published: false)
  end
  
  def increment_views!
    increment!(:views_count)
  end
  
  def increment_shares!
    increment!(:shares_count)
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
    # Check if user owns artist's fan pass
    artist.fan_passes.joins(:fan_pass_nfts).exists?(fan_pass_nfts: { user: user, status: :active })
  end
  
  def allowed_duration(user)
    return duration if free?
    return duration if user && (owns_nft?(user) || user_purchased?(user))
    return preview_duration if preview_only?
    return 0 if nft_required? || paid?
    duration
  end
  
  # Engagement metrics
  def engagement_rate
    return 0 if views_count.zero?
    ((likes_count + shares_count * 2).to_f / views_count * 100).round(2)
  end
  
  def completion_rate
    return 0 if mini_views.count.zero?
    (mini_views.where(completed: true).count.to_f / mini_views.count * 100).round(2)
  end
  
  private
  
  def update_search_vector
    return unless id
    artist_name = artist&.name || ''
    self.class.connection.execute(
      "UPDATE minis SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B') " \
      "WHERE id = #{id}"
    )
  end
end

