class Purchase < ApplicationRecord
  belongs_to :user
  belongs_to :purchasable, polymorphic: true
  
  validates :price_paid, presence: true, numericality: { greater_than: 0 }
  validates :transaction_signature, presence: true
end
