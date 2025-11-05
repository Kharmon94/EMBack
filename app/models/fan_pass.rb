class FanPass < ApplicationRecord
  belongs_to :artist
  has_many :fan_pass_nfts, dependent: :destroy
  has_many :dividends, through: :fan_pass_nfts
  
  enum :distribution_type, { paid: 0, airdrop: 1, hybrid: 2 }, prefix: true
  
  validates :name, :description, :max_supply, presence: true
  validates :max_supply, numericality: { greater_than: 0, less_than_or_equal_to: 10000 }
  validates :dividend_percentage, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 50 
  }, allow_nil: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :collection_mint, uniqueness: true, allow_nil: true
  
  # Ensure perks is always a hash
  after_initialize :set_default_perks, if: :new_record?
  
  # Scopes
  scope :nft_enabled, -> { where.not(collection_mint: nil) }
  scope :active_passes, -> { where(active: true) }
  scope :with_dividends, -> { where('dividend_percentage > 0') }
  
  def set_default_perks
    self.perks ||= {
      'access' => [],
      'discounts' => [],
      'content' => [],
      'events' => [],
      'governance' => []
    }
    self.revenue_sources ||= ['streaming', 'sales', 'merch']
  end
  
  def minted_count
    fan_pass_nfts.count
  end
  
  def active_count
    fan_pass_nfts.active.count
  end
  
  def available_supply
    max_supply - minted_count
  end
  
  def sold_out?
    available_supply <= 0
  end
  
  def has_dividends?
    dividend_percentage.present? && dividend_percentage > 0
  end
  
  # Calculate dividend pool and per-holder amount
  def calculate_dividend(artist_revenue, period_start, period_end)
    return { total_pool: 0, per_holder: 0 } unless has_dividends?
    
    total_pool = artist_revenue * (dividend_percentage / 100.0)
    active_holders = active_count
    per_holder = active_holders > 0 ? total_pool / active_holders : 0
    
    {
      total_pool: total_pool.round(8),
      per_holder: per_holder.round(8),
      active_holders: active_holders,
      artist_revenue: artist_revenue,
      dividend_rate: dividend_percentage,
      period_start: period_start,
      period_end: period_end
    }
  end
  
  def total_perks_count
    return 0 unless perks.is_a?(Hash)
    perks.values.sum { |v| v.is_a?(Array) ? v.length : 0 }
  end
end
