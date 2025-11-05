class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  
  enum :status, { pending: 0, paid: 1, processing: 2, shipped: 3, delivered: 4, cancelled: 5 }, default: :pending
  
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: [:paid, :processing, :shipped]) }
end
