class CartOrder < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :nullify
  
  enum :status, { pending: 0, paid: 1, completed: 2, cancelled: 3 }, default: :pending
  enum :payment_status, { unpaid: 0, processing: 1, confirmed: 2, failed: 3 }, default: :unpaid
  
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  
  def total_with_shipping
    orders.sum { |order| order.total_amount + (order.shipping_fee || 0) }
  end
  
  def sellers_breakdown
    orders.includes(order_items: { merch_item: :artist }).map do |order|
      artist = order.order_items.first&.merch_item&.artist
      {
        artist_id: artist&.id,
        artist_name: artist&.name,
        wallet_address: artist&.wallet_address,
        items_total: order.total_amount,
        shipping_fee: order.shipping_fee || 0,
        seller_amount: order.seller_amount || 0,
        order_id: order.id
      }
    end
  end
  
  def all_items_shipped?
    orders.all? { |o| o.shipped? || o.delivered? }
  end
  
  def all_items_delivered?
    orders.all?(&:delivered?)
  end
end

