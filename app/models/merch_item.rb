class MerchItem < ApplicationRecord
  belongs_to :artist
  belongs_to :product_category, optional: true
  has_many :merch_item_tags, dependent: :destroy
  has_many :product_tags, through: :merch_item_tags
  has_many :product_variants, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :recently_viewed_items, dependent: :destroy
  has_many :order_items, dependent: :destroy
  
  validates :title, :price, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :inventory_count, numericality: { greater_than_or_equal_to: 0 }
  
  scope :in_stock, -> { where('inventory_count > 0') }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(category_id) { where(product_category_id: category_id) }
  scope :token_gated, -> { where(token_gated: true) }
  scope :limited_edition, -> { where(limited_edition: true) }
  scope :popular, -> { order(purchase_count: :desc) }
  scope :trending, -> { where('view_count > ?', 100).order(view_count: :desc) }
  scope :highly_rated, -> { where('rating_average >= ?', 4.0).order(rating_average: :desc) }
  
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
  
  def in_stock?
    inventory_count && inventory_count > 0
  end
  
  def low_stock?
    in_stock? && inventory_count <= low_stock_threshold
  end
  
  def available_sizes
    product_variants.available.pluck(:size).uniq.compact
  end
  
  def available_colors
    product_variants.available.pluck(:color).uniq.compact
  end
  
  def has_variants?
    product_variants.exists?
  end
  
  def increment_view_count!
    increment!(:view_count)
  end
  
  def increment_purchase_count!
    increment!(:purchase_count)
  end
  
  private
  
  def update_search_vector
    return unless id
    artist_name = artist&.name || ''
    self.class.connection.execute(
      "UPDATE merch_items SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(brand || '')}, '')), 'C') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B') " \
      "WHERE id = #{id}"
    )
  end
end
