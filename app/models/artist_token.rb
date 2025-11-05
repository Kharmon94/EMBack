class ArtistToken < ApplicationRecord
  belongs_to :artist
  has_many :trades, dependent: :destroy
  has_many :liquidity_pools, dependent: :destroy
  has_many :airdrops, dependent: :destroy
  
  validates :name, :symbol, :mint_address, presence: true
  validates :mint_address, uniqueness: true
  validates :graduated, inclusion: { in: [true, false] }
  validate :one_token_per_wallet, on: :create
  
  scope :graduated, -> { where(graduated: true) }
  scope :active, -> { where(graduated: false) }
  
  def market_cap_usd
    (supply.to_f * price_usd.to_f) if supply && price_usd
  end
  
  def ready_to_graduate?
    return false if graduated
    market_cap_usd && market_cap_usd >= 69_000 # $69k threshold
  end
  
  private
  
  # Ensure one token per wallet address
  # This validation provides defense-in-depth alongside relationship constraints
  def one_token_per_wallet
    return unless artist&.user&.wallet_address
    
    existing_token = ArtistToken.joins(artist: :user)
                                 .where(users: { wallet_address: artist.user.wallet_address })
                                 .where.not(id: id)
                                 .exists?
    
    if existing_token
      errors.add(:base, 'This wallet has already created a token. Each wallet can only create one artist token.')
    end
  end
end
