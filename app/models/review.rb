class Review < ApplicationRecord
  belongs_to :user
  belongs_to :merch_item, counter_cache: :rating_count
  belongs_to :order, optional: true
  has_many :review_votes, dependent: :destroy
  
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :merch_item_id, message: 'can only review once per product' }
  
  scope :verified, -> { where(verified_purchase: true) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :recent, -> { order(created_at: :desc) }
  scope :most_helpful, -> { order(helpful_count: :desc) }
  
  after_save :update_product_rating
  after_destroy :update_product_rating
  
  private
  
  def update_product_rating
    merch_item.update_columns(
      rating_average: merch_item.reviews.average(:rating) || 0,
      rating_count: merch_item.reviews.count
    )
  end
end

