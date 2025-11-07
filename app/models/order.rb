class Order < ApplicationRecord
  belongs_to :user
  belongs_to :cart_order, optional: true
  has_many :order_items, dependent: :destroy
  # Note: order_items use polymorphic 'orderable' (MerchItem, FanPass, Track, Album)
  # Use order.order_items.map(&:orderable) to get actual items
  has_many :reviews, dependent: :nullify
  has_many :conversations, dependent: :nullify
  
  enum :status, { pending: 0, paid: 1, processing: 2, shipped: 3, delivered: 4, cancelled: 5 }, default: :pending
  
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:paid, :processing, :shipped]) }
  scope :fulfilled, -> { where(status: [:shipped, :delivered]) }
  scope :pending_fulfillment, -> { where(status: [:paid, :processing]) }
  scope :child_orders, -> { where.not(cart_order_id: nil) }
  scope :standalone_orders, -> { where(cart_order_id: nil) }
  scope :for_artist, ->(artist_id) {
    joins(order_items: { merch_item: :artist })
      .where(merch_items: { artist_id: artist_id })
      .distinct
  }
  
  def seller
    # Get the artist from the first order item
    order_items.first&.merch_item&.artist
  end
  
  def mark_as_shipped!(tracking_number, carrier)
    update!(
      status: :shipped,
      shipped_at: Time.current,
      tracking_number: tracking_number,
      carrier: carrier
    )
  end
  
  def can_be_reviewed_by?(user)
    user_id == user.id && status == :delivered
  end
end
