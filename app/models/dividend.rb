class Dividend < ApplicationRecord
  belongs_to :fan_pass_nft
  
  enum :status, {
    pending: 0,
    processing: 1,
    paid: 2,
    failed: 3
  }, prefix: true
  
  enum :source, {
    streaming: 0,      # From streaming royalties
    sales: 1,          # From music sales
    events: 2,         # From ticket sales
    tokens: 3,         # From token trading fees
    merch: 4           # From merchandise sales
  }, prefix: true
  
  validates :amount, numericality: { greater_than: 0 }
  validates :period_start, :period_end, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_period, ->(start_date, end_date) { 
    where('period_start >= ? AND period_end <= ?', start_date, end_date) 
  }
  scope :paid, -> { status_paid }
  scope :pending, -> { status_pending }
  
  # Mark as paid
  def mark_as_paid!(transaction_sig)
    update!(
      status: :paid,
      transaction_signature: transaction_sig,
      updated_at: Time.current
    )
    
    # Update total earned on parent NFT
    fan_pass_nft.increment!(:total_dividends_earned, amount)
    fan_pass_nft.update!(last_dividend_at: Time.current)
  end
  
  # Retry failed payment
  def retry!
    return false unless failed?
    update!(status: :pending)
  end
end

