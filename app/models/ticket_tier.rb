class TicketTier < ApplicationRecord
  belongs_to :event
  has_many :tickets, dependent: :destroy
  
  validates :name, :price, :quantity, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, :sold, numericality: { greater_than_or_equal_to: 0 }
  
  before_validation :initialize_sold, on: :create
  
  def available
    quantity - (sold || 0)
  end
  
  def sold_out?
    available <= 0
  end
  
  # All-in pricing (includes platform fee and processing)
  def total_price(platform_fee_percent = 0.05, processing_fee = 1.50)
    price + (price * platform_fee_percent) + processing_fee
  end
  
  private
  
  def initialize_sold
    self.sold ||= 0
  end
end
