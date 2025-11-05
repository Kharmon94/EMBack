class DexService
  PLATFORM_FEE_PERCENTAGE = 0.002 # 0.2% platform fee
  LP_FEE_PERCENTAGE = 0.003 # 0.3% LP fee
  
  def initialize
    @solana = SolanaService.new
  end
  
  # Swap tokens using in-house DEX or route to Raydium
  def swap(from_mint, to_mint, amount, min_amount_out, user_wallet, slippage = 0.01)
    # Find or determine pool
    pool = find_pool(from_mint, to_mint)
    
    unless pool
      return {
        error: 'No liquidity pool found for this pair',
        suggestion: 'Try Raydium or create a pool'
      }
    end
    
    # Calculate output amount based on constant product formula
    # x * y = k
    result = if pool.in_house?
               swap_in_house(pool, from_mint, amount, min_amount_out)
             else
               swap_raydium(pool, from_mint, to_mint, amount, min_amount_out)
             end
    
    result
  end
  
  # Add liquidity to pool
  def add_liquidity(pool_id, token_amount, sol_amount, user_wallet)
    pool = LiquidityPool.find(pool_id)
    
    # Calculate LP tokens to mint
    if pool.reserve_token.zero? || pool.reserve_sol.zero?
      # First liquidity provider
      lp_tokens = Math.sqrt(token_amount * sol_amount)
    else
      # Proportional to existing pool
      lp_tokens = [
        (token_amount * pool.tvl) / pool.reserve_token,
        (sol_amount * pool.tvl) / pool.reserve_sol
      ].min
    end
    
    # TODO: Execute on-chain liquidity addition
    # TODO: Mint LP tokens to user
    
    # Update pool reserves
    new_token_reserve = pool.reserve_token + token_amount
    new_sol_reserve = pool.reserve_sol + sol_amount
    
    pool.update_reserves!(new_token_reserve, new_sol_reserve)
    
    {
      success: true,
      lp_tokens: lp_tokens,
      pool: pool_json(pool),
      message: 'Liquidity added successfully'
    }
  rescue => e
    Rails.logger.error("Add liquidity error: #{e.message}")
    { error: e.message }
  end
  
  # Remove liquidity from pool
  def remove_liquidity(pool_id, lp_tokens, user_wallet)
    pool = LiquidityPool.find(pool_id)
    
    # Calculate token and SOL amounts to return
    # Proportional to LP tokens being burned
    total_lp_supply = pool.tvl # Simplified - should track actual LP supply
    
    token_amount = (lp_tokens / total_lp_supply) * pool.reserve_token
    sol_amount = (lp_tokens / total_lp_supply) * pool.reserve_sol
    
    # TODO: Execute on-chain liquidity removal
    # TODO: Burn LP tokens
    # TODO: Transfer tokens and SOL back to user
    
    # Update pool reserves
    new_token_reserve = pool.reserve_token - token_amount
    new_sol_reserve = pool.reserve_sol - sol_amount
    
    pool.update_reserves!(new_token_reserve, new_sol_reserve)
    
    {
      success: true,
      token_amount: token_amount,
      sol_amount: sol_amount,
      pool: pool_json(pool),
      message: 'Liquidity removed successfully'
    }
  rescue => e
    Rails.logger.error("Remove liquidity error: #{e.message}")
    { error: e.message }
  end
  
  # Get pool information
  def get_pool_info(pool_id)
    pool = LiquidityPool.find(pool_id)
    
    {
      pool: pool_json(pool),
      price: pool.price,
      volume_24h: calculate_volume(pool, 24.hours),
      apy: calculate_apy(pool)
    }
  end
  
  private
  
  def find_pool(from_mint, to_mint)
    # Search for pool containing this pair
    # Simplified - in production, would check both directions and multiple DEXs
    LiquidityPool.joins(:artist_token)
                 .where('artist_tokens.mint_address = ? OR artist_tokens.mint_address = ?', from_mint, to_mint)
                 .first
  end
  
  def swap_in_house(pool, from_mint, amount_in, min_amount_out)
    # Constant product formula: x * y = k
    token = pool.artist_token
    
    # Determine which direction (token → SOL or SOL → token)
    is_token_to_sol = (from_mint == token.mint_address)
    
    if is_token_to_sol
      # Swapping token for SOL
      amount_out = calculate_output(pool.reserve_token, pool.reserve_sol, amount_in)
    else
      # Swapping SOL for token
      amount_out = calculate_output(pool.reserve_sol, pool.reserve_token, amount_in)
    end
    
    # Check slippage
    if amount_out < min_amount_out
      return { error: 'Slippage too high', expected: amount_out, minimum: min_amount_out }
    end
    
    # Apply fees
    platform_fee = amount_out * PLATFORM_FEE_PERCENTAGE
    lp_fee = amount_out * LP_FEE_PERCENTAGE
    final_amount_out = amount_out - platform_fee - lp_fee
    
    # TODO: Execute on-chain swap
    
    # Update reserves
    if is_token_to_sol
      pool.update_reserves!(
        pool.reserve_token + amount_in,
        pool.reserve_sol - final_amount_out
      )
    else
      pool.update_reserves!(
        pool.reserve_token - final_amount_out,
        pool.reserve_sol + amount_in
      )
    end
    
    {
      success: true,
      amount_in: amount_in,
      amount_out: final_amount_out,
      platform_fee: platform_fee,
      lp_fee: lp_fee,
      price: amount_in / final_amount_out,
      pool: pool_json(pool)
    }
  end
  
  def swap_raydium(pool, from_mint, to_mint, amount, min_amount_out)
    # TODO: Integrate with Raydium SDK
    # For now, return placeholder
    
    Rails.logger.warn("Raydium swap not yet implemented")
    
    {
      error: 'Raydium integration coming soon',
      fallback: 'Use in-house DEX for now'
    }
  end
  
  def calculate_output(reserve_in, reserve_out, amount_in)
    # Constant product formula: (x + dx) * (y - dy) = x * y
    # dy = (y * dx) / (x + dx)
    
    # Include fees in calculation
    amount_in_with_fee = amount_in * (1 - PLATFORM_FEE_PERCENTAGE - LP_FEE_PERCENTAGE)
    
    numerator = reserve_out * amount_in_with_fee
    denominator = reserve_in + amount_in_with_fee
    
    (numerator / denominator).floor(8)
  end
  
  def calculate_volume(pool, period)
    # Calculate trading volume for the pool in the given period
    # This would come from Trade records or on-chain data
    
    # Placeholder
    pool.volume_24h || 0
  end
  
  def calculate_apy(pool)
    # Calculate APY based on fees collected
    # APY = (fees_24h / tvl) * 365 * 100
    
    return 0 if pool.tvl.zero?
    
    fees_24h = calculate_volume(pool, 24.hours) * (LP_FEE_PERCENTAGE + PLATFORM_FEE_PERCENTAGE)
    apy = (fees_24h / pool.tvl) * 365 * 100
    
    apy.round(2)
  end
  
  def pool_json(pool)
    {
      id: pool.id,
      platform: pool.platform,
      pool_address: pool.pool_address,
      reserve_token: pool.reserve_token,
      reserve_sol: pool.reserve_sol,
      tvl: pool.tvl,
      price: pool.price,
      token: {
        id: pool.artist_token.id,
        name: pool.artist_token.name,
        symbol: pool.artist_token.symbol,
        mint_address: pool.artist_token.mint_address
      }
    }
  end
end

