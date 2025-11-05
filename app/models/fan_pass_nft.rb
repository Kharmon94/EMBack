class FanPassNft < ApplicationRecord
  belongs_to :fan_pass
  belongs_to :user, optional: true  # Null if unclaimed or burned
  has_many :dividends, dependent: :destroy
  
  enum :status, {
    unclaimed: 0,      # Minted but not claimed
    active: 1,         # Owned and active
    transferred: 2,    # Sold on secondary market
    burned: 3          # NFT burned
  }, prefix: true
  
  validates :nft_mint, presence: true, uniqueness: true
  validates :edition_number, presence: true
  validates :edition_number, uniqueness: { scope: :fan_pass_id }
  
  scope :owned, -> { where.not(user_id: nil) }
  scope :claimable, -> { where(status: :unclaimed) }
  
  # Check if user owns this NFT
  def owned_by?(user)
    self.user_id == user&.id && active?
  end
  
  # Transfer to new owner (secondary sale)
  def transfer_to!(new_owner, transaction_signature)
    update!(
      user: new_owner,
      status: :transferred,
      updated_at: Time.current
    )
    
    # Log the transfer
    Rails.logger.info("Fan Pass NFT #{id} transferred to #{new_owner.wallet_address}")
    
    # TODO: Verify on-chain transfer
    true
  end
  
  # Calculate total dividends earned
  def total_earned
    dividends.paid.sum(:amount)
  end
  
  # Get pending dividends
  def pending_dividends
    dividends.pending.sum(:amount)
  end
  
  # Check if eligible for dividends
  def dividend_eligible?
    active? && user.present?
  end
end

