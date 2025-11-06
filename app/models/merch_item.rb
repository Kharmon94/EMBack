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
  
  # Full-text search
  scope :search, ->(query) {
    return all if query.blank?
    where("search_vector @@ plainto_tsquery('english', ?)", query)
      .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
  }
  
  before_save :update_search_vector
  
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
    artist_name = artist&.name || ''
    self.search_vector = Arel.sql(
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(brand || '')}, '')), 'C') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B')"
    )
  end
end
