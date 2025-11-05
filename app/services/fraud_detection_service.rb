class FraudDetectionService
  # Fraud detection patterns and rules
  
  # Stream fraud detection
  def self.detect_stream_fraud(user, track, request_data = {})
    flags = []
    
    # Check 1: Rapid repeated streams
    recent_stream_count = Stream.where(user: user, track: track)
                               .where('listened_at >= ?', 1.hour.ago)
                               .count
    
    flags << 'rapid_repeat_streams' if recent_stream_count > 10
    
    # Check 2: Unusual listening patterns (too many tracks in short time)
    recent_total_streams = Stream.where(user: user)
                                .where('listened_at >= ?', 1.hour.ago)
                                .count
    
    flags << 'excessive_streaming' if recent_total_streams > 100
    
    # Check 3: Bot-like duration patterns (always exactly 30 seconds)
    exact_30_second_streams = Stream.where(user: user)
                                   .where(duration: 30)
                                   .where('listened_at >= ?', 24.hours.ago)
                                   .count
    
    total_recent_streams = Stream.where(user: user)
                                .where('listened_at >= ?', 24.hours.ago)
                                .count
    
    if total_recent_streams > 0
      exact_ratio = exact_30_second_streams.to_f / total_recent_streams
      flags << 'suspicious_duration_pattern' if exact_ratio > 0.9
    end
    
    # Check 4: Device fingerprint analysis (requires request data)
    if request_data[:user_agent].present?
      flags << 'suspicious_user_agent' if bot_user_agent?(request_data[:user_agent])
    end
    
    # Check 5: IP address analysis
    if request_data[:ip_address].present?
      recent_users_same_ip = User.joins(:streams)
                                 .where(streams: { listened_at: 1.hour.ago.. })
                                 .where('streams.ip_address = ?', request_data[:ip_address])
                                 .distinct
                                 .count
      
      flags << 'multiple_users_same_ip' if recent_users_same_ip > 5
    end
    
    {
      suspicious: flags.any?,
      flags: flags,
      risk_score: calculate_risk_score(flags),
      action: determine_action(flags)
    }
  end
  
  # Trade fraud detection
  def self.detect_trade_fraud(user, trade_params)
    flags = []
    
    # Check 1: Wash trading (rapid buy/sell)
    recent_trades = Trade.where(user: user, artist_token_id: trade_params[:artist_token_id])
                        .where('created_at >= ?', 5.minutes.ago)
                        .order(created_at: :desc)
                        .limit(10)
    
    if recent_trades.count >= 5
      buy_count = recent_trades.where(trade_type: :buy).count
      sell_count = recent_trades.where(trade_type: :sell).count
      
      flags << 'wash_trading' if (buy_count - sell_count).abs <= 1
    end
    
    # Check 2: Unusual trade amounts
    amount = trade_params[:amount].to_f
    token = ArtistToken.find_by(id: trade_params[:artist_token_id])
    
    if token
      avg_trade_amount = Trade.where(artist_token: token)
                             .where('created_at >= ?', 24.hours.ago)
                             .average(:amount)
                             .to_f
      
      flags << 'unusual_trade_size' if avg_trade_amount > 0 && amount > avg_trade_amount * 10
    end
    
    # Check 3: New user with large trade
    if user.created_at > 1.hour.ago && amount > 1000
      flags << 'new_user_large_trade'
    end
    
    {
      suspicious: flags.any?,
      flags: flags,
      risk_score: calculate_risk_score(flags),
      action: determine_action(flags)
    }
  end
  
  # Ticket fraud detection
  def self.detect_ticket_fraud(user, ticket_purchase_params)
    flags = []
    
    # Check 1: Bulk buying (scalping)
    recent_purchases = Purchase.where(user: user)
                               .where('created_at >= ?', 1.hour.ago)
                               .where(purchasable_type: 'TicketTier')
                               .count
    
    flags << 'bulk_ticket_purchase' if recent_purchases > 10
    
    # Check 2: Multiple failed attempts
    # TODO: Track failed purchase attempts
    
    # Check 3: Suspicious wallet age
    if user.created_at > 10.minutes.ago
      flags << 'new_account_ticket_purchase'
    end
    
    {
      suspicious: flags.any?,
      flags: flags,
      risk_score: calculate_risk_score(flags),
      action: determine_action(flags)
    }
  end
  
  # Content spam/fraud detection
  def self.detect_content_fraud(content_type, content_params, creator)
    flags = []
    
    case content_type
    when 'album', 'track'
      # Check 1: Excessive uploads
      recent_uploads = case content_type
                      when 'album'
                        Album.where(artist: creator.artist).where('created_at >= ?', 1.day.ago).count
                      when 'track'
                        Track.joins(:album).where(albums: { artist_id: creator.artist.id }).where('tracks.created_at >= ?', 1.day.ago).count
                      end
      
      threshold = content_type == 'album' ? 10 : 50
      flags << 'excessive_uploads' if recent_uploads > threshold
      
      # Check 2: Duplicate content (title similarity)
      # TODO: Implement fuzzy matching for duplicate detection
      
      # Check 3: Suspicious metadata
      flags << 'missing_metadata' if content_params[:title].blank? || content_params[:title].length < 3
    
    when 'event'
      # Check 1: Excessive event creation
      recent_events = Event.where(artist: creator.artist).where('created_at >= ?', 1.day.ago).count
      flags << 'excessive_events' if recent_events > 5
      
      # Check 2: Unrealistic ticket prices
      if content_params[:ticket_tiers].present?
        max_price = content_params[:ticket_tiers].map { |t| t[:price].to_f }.max
        flags << 'unrealistic_pricing' if max_price > 10_000
      end
    end
    
    {
      suspicious: flags.any?,
      flags: flags,
      risk_score: calculate_risk_score(flags),
      action: determine_action(flags)
    }
  end
  
  private
  
  def self.bot_user_agent?(user_agent)
    bot_patterns = [
      /bot/i, /crawl/i, /spider/i, /scraper/i,
      /curl/i, /wget/i, /python/i, /java/i
    ]
    
    bot_patterns.any? { |pattern| user_agent.match?(pattern) }
  end
  
  def self.calculate_risk_score(flags)
    # Risk scores: 0-100
    base_scores = {
      'rapid_repeat_streams' => 30,
      'excessive_streaming' => 40,
      'suspicious_duration_pattern' => 50,
      'suspicious_user_agent' => 60,
      'multiple_users_same_ip' => 45,
      'wash_trading' => 70,
      'unusual_trade_size' => 20,
      'new_user_large_trade' => 35,
      'bulk_ticket_purchase' => 50,
      'new_account_ticket_purchase' => 25,
      'excessive_uploads' => 40,
      'missing_metadata' => 15,
      'excessive_events' => 30,
      'unrealistic_pricing' => 25
    }
    
    score = flags.sum { |flag| base_scores[flag] || 10 }
    [score, 100].min # Cap at 100
  end
  
  def self.determine_action(flags)
    risk_score = calculate_risk_score(flags)
    
    case risk_score
    when 0..20
      'allow'
    when 21..50
      'flag_for_review'
    when 51..70
      'require_verification'
    else
      'block'
    end
  end
end

