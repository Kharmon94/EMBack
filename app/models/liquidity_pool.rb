class LiquidityPool < ApplicationRecord
  belongs_to :artist_token
  
  enum :platform, { in_house: 0, raydium_cpmm: 1, raydium_clmm: 2 }, default: :in_house
  
  validates :pool_address, presence: true, uniqueness: true
  validates :reserve_token, :reserve_sol, numericality: { greater_than_or_equal_to: 0 }
  
  def price
    return 0 if reserve_token.zero?
    reserve_sol / reserve_token
  end
  
  def update_reserves!(token_amount, sol_amount)
    update!(
      reserve_token: token_amount,
      reserve_sol: sol_amount,
      tvl: (sol_amount * 2) # Simplified TVL calculation
    )
  end
end
