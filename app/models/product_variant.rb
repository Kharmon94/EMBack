class ProductVariant < ApplicationRecord
  belongs_to :merch_item
  
  validates :sku, presence: true, uniqueness: true
  validates :inventory_count, numericality: { greater_than_or_equal_to: 0 }
  
  scope :available, -> { where(available: true).where('inventory_count > 0') }
  scope :low_stock, -> { where('inventory_count > 0 AND inventory_count <= low_stock_threshold') }
  scope :out_of_stock, -> { where(inventory_count: 0) }
  
  def in_stock?
    available && inventory_count > 0
  end
  
  def low_stock?
    inventory_count > 0 && inventory_count <= low_stock_threshold
  end
  
  def final_price
    merch_item.price + (price_modifier || 0)
  end
  
  def variant_name
    [size, color, material].compact.join(' / ')
  end
end

