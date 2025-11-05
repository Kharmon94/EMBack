class Trade < ApplicationRecord
  belongs_to :user
  belongs_to :artist_token
  
  enum :trade_type, { buy: 0, sell: 1 }, default: :buy
  
  validates :amount, :price, :trade_type, presence: true
  validates :amount, :price, numericality: { greater_than: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_token, ->(token_id) { where(artist_token_id: token_id) }
end
