class FanPassService
  # Platform fees
  FAN_PASS_SALE_FEE = 0.10        # 10% on initial NFT sales
  FAN_PASS_SECONDARY_FEE = 0.05   # 5% royalty on secondary sales
  
  def initialize(fan_pass)
    @fan_pass = fan_pass
    @artist = fan_pass.artist
  end
  
  # Mint fan pass NFT to user
  def mint_nft(user, payment_signature)
    # Check availability
    raise "Fan pass sold out" if @fan_pass.sold_out?
    
    # Verify payment if required
    if @fan_pass.paid? && @fan_pass.price > 0
      # TODO: Verify Solana transaction
      unless payment_signature
        raise "Payment signature required"
      end
    end
    
    # Calculate platform fee
    platform_fee = @fan_pass.paid? ? (@fan_pass.price * FAN_PASS_SALE_FEE) : 0
    artist_receives = @fan_pass.price - platform_fee
    
    # Get next edition number
    edition_number = @fan_pass.minted_count + 1
    
    # Create NFT record
    nft = @fan_pass.fan_pass_nfts.create!(
      user: user,
      nft_mint: generate_nft_mint,  # TODO: Actual Metaplex minting
      edition_number: edition_number,
      status: :active,
      claimed_at: Time.current
    )
    
    # Increment minted count
    @fan_pass.increment!(:minted_count)
    
    # Process platform fee
    if platform_fee > 0
      PlatformTokenService.new.process_fee_collection(platform_fee, 'fan_pass_sale')
      
      # Track in metrics
      metric = PlatformMetric.find_or_create_by(date: Date.today) do |m|
        m.fan_pass_fees_collected = 0
      end
      metric.increment!(:fan_pass_fees_collected, platform_fee)
    end
    
    {
      nft: nft,
      edition_number: edition_number,
      platform_fee: platform_fee,
      artist_receives: artist_receives,
      nft_mint: nft.nft_mint
    }
  end
  
  # Calculate and create dividend records for a period
  def distribute_dividends(period_start, period_end, revenue_by_source)
    return { error: 'No dividends configured' } unless @fan_pass.has_dividends?
    
    # Calculate total artist revenue from enabled sources
    total_revenue = revenue_by_source.select { |source, _| 
      @fan_pass.revenue_sources.include?(source.to_s) 
    }.values.sum
    
    return { error: 'No revenue in period' } if total_revenue.zero?
    
    # Calculate dividend pool
    dividend_calc = @fan_pass.calculate_dividend(total_revenue, period_start, period_end)
    
    return { error: 'No active holders' } if dividend_calc[:active_holders].zero?
    
    # Create dividend records for each active NFT
    dividends_created = []
    
    @fan_pass.fan_pass_nfts.active.each do |nft|
      # Determine source breakdown (proportional)
      revenue_by_source.each do |source, amount|
        next unless @fan_pass.revenue_sources.include?(source.to_s)
        next if amount.zero?
        
        source_dividend = (amount * (@fan_pass.dividend_percentage / 100.0)) / dividend_calc[:active_holders]
        
        dividend = nft.dividends.create!(
          amount: source_dividend,
          source: source,
          status: :pending,
          period_start: period_start,
          period_end: period_end,
          calculation_details: "#{@fan_pass.dividend_percentage}% of #{amount} #{source} revenue / #{dividend_calc[:active_holders]} holders"
        )
        
        dividends_created << dividend
      end
    end
    
    {
      success: true,
      total_pool: dividend_calc[:total_pool],
      per_holder: dividend_calc[:per_holder],
      dividends_created: dividends_created.length,
      active_holders: dividend_calc[:active_holders]
    }
  end
  
  # Batch process pending dividend payments
  def process_pending_dividends
    pending = Dividend.joins(:fan_pass_nft)
                     .where(fan_pass_nfts: { fan_pass_id: @fan_pass.id })
                     .pending
                     .group_by(&:fan_pass_nft_id)
    
    results = []
    
    pending.each do |nft_id, nft_dividends|
      nft = FanPassNft.find(nft_id)
      next unless nft.user  # Skip if no owner
      
      total_amount = nft_dividends.sum(&:amount)
      
      # TODO: Execute Solana transfer to nft.user.wallet_address
      # For now, mark as processing
      nft_dividends.each { |d| d.update!(status: :processing) }
      
      # Simulate successful transfer
      transaction_sig = "DIV_#{SecureRandom.hex(32)}"
      
      nft_dividends.each do |dividend|
        dividend.mark_as_paid!(transaction_sig)
      end
      
      results << {
        nft_id: nft.id,
        user_wallet: nft.user.wallet_address,
        amount: total_amount,
        transaction: transaction_sig
      }
    end
    
    {
      success: true,
      payments_processed: results.length,
      total_distributed: results.sum { |r| r[:amount] },
      results: results
    }
  end
  
  # Check if user has this fan pass
  def user_has_pass?(user)
    @fan_pass.fan_pass_nfts.active.exists?(user: user)
  end
  
  # Verify user has specific perk
  def user_has_perk?(user, perk_category, perk_name)
    return false unless user_has_pass?(user)
    return false unless @fan_pass.perks.is_a?(Hash)
    
    perks_array = @fan_pass.perks[perk_category.to_s] || []
    perks_array.include?(perk_name)
  end
  
  private
  
  def generate_nft_mint
    # TODO: Actual Metaplex NFT minting
    # For now, generate placeholder
    "FANPASS_#{@fan_pass.id}_#{SecureRandom.hex(16)}"
  end
end

