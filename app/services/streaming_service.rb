class StreamingService
  ELIGIBLE_STREAM_DURATION = 30 # seconds
  COOLDOWN_WINDOW = 5 # minutes
  MAX_STREAMS_PER_HOUR = 100 # Anti-fraud threshold
  
  # Clean payout structure (no ads)
  PAYOUT_RATES = {
    free: 0.0005,          # Standard rate for free streaming
    preview_only: 0.0001,  # Minimal for previews
    nft_holder: 0.001      # Premium rate for NFT holders
  }
  
  def initialize(user, track)
    @user = user
    @track = track
    @artist = track.album.artist
    @album = track.album
    @owns_nft = check_nft_ownership
  end
  
  # Check user's access level for current track
  def check_access
    # NFT holders bypass all restrictions
    if @owns_nft
      return {
        allowed: true,
        quality: 'lossless',
        duration: 'unlimited',
        downloadable: true,
        reason: 'NFT ownership verified',
        tier: 'premium'
      }
    end
    
    # Non-owners: check track settings
    case @track.access_tier
    when 'free'
      {
        allowed: true,
        quality: @track.free_quality, # 'standard' or 'high'
        duration: 'unlimited',
        downloadable: false,
        reason: 'Free streaming by artist',
        tier: 'free'
      }
      
    when 'preview_only'
      {
        allowed: true,
        quality: 'preview',
        duration: 30, # seconds only
        downloadable: false,
        reason: 'Preview access - buy NFT for full track',
        tier: 'preview',
        upgrade_url: "/albums/#{@album.id}/purchase"
      }
      
    when 'nft_required'
      {
        allowed: false,
        quality: nil,
        duration: 0,
        downloadable: false,
        reason: 'NFT ownership required',
        tier: 'locked',
        purchase_url: "/albums/#{@album.id}/purchase"
      }
    end
  end
  
  # Log a stream event
  def log_stream(duration_seconds, device_info = {})
    access = check_access
    
    # Block if not allowed
    unless access[:allowed]
      return { 
        success: false,
        error: access[:reason],
        purchase_url: access[:purchase_url]
      }
    end
    
    # Enforce preview duration limits
    if access[:duration] != 'unlimited'
      duration_seconds = [duration_seconds, access[:duration]].min
    end
    
    # Validation
    return { error: 'Invalid duration', eligible: false } if duration_seconds < 1
    
    # Check for fraud
    if detect_fraud?
      Rails.logger.warn("Potential streaming fraud detected for user #{@user.id}, track #{@track.id}")
      return { error: 'Too many streams detected', eligible: false }
    end
    
    # Check cooldown window to prevent duplicate counting
    if Stream.recent_stream_exists?(@user.id, @track.id, COOLDOWN_WINDOW)
      return { error: 'Stream already counted recently', eligible: false }
    end
    
    # Create stream record with access tracking
    stream = Stream.create!(
      user: @user,
      track: @track,
      duration: duration_seconds,
      listened_at: Time.current,
      nft_holder: @owns_nft,
      access_tier: access[:tier],
      quality: access[:quality]
    )
    
    # Check if eligible for payout (30+ seconds)
    eligible = stream.eligible_for_payout?
    
    if eligible
      # Calculate payout based on access tier
      payout_rate = @owns_nft ? PAYOUT_RATES[:nft_holder] : PAYOUT_RATES[@track.access_tier.to_sym]
      distribute_revenue(stream, payout_rate)
      
      # Update metrics
      update_platform_metrics
    end
    
    {
      success: true,
      eligible: eligible,
      stream_id: stream.id,
      quality: access[:quality],
      tier: access[:tier],
      can_download: access[:downloadable],
      message: eligible ? 'Stream counted' : 'Stream logged (not eligible for payout)'
    }
  rescue => e
    Rails.logger.error("Stream logging error: #{e.message}")
    { error: e.message, eligible: false }
  end
  
  # Calculate revenue for a track
  def calculate_track_revenue(track, time_period = 30.days)
    eligible_streams = track.streams
      .where("duration >= ?", ELIGIBLE_STREAM_DURATION)
      .where("listened_at >= ?", time_period.ago)
      .count
    
    eligible_streams * PAYOUT_PER_STREAM
  end
  
  # Get streaming stats for artist
  def self.artist_stats(artist, time_period = 30.days)
    tracks = Track.joins(:album).where(albums: { artist_id: artist.id })
    
    {
      total_streams: Stream.where(track: tracks).where("listened_at >= ?", time_period.ago).count,
      eligible_streams: Stream.where(track: tracks).where("duration >= ?", ELIGIBLE_STREAM_DURATION).where("listened_at >= ?", time_period.ago).count,
      unique_listeners: Stream.where(track: tracks).where("listened_at >= ?", time_period.ago).select(:user_id).distinct.count,
      total_listen_time: Stream.where(track: tracks).where("listened_at >= ?", time_period.ago).sum(:duration),
      estimated_revenue: tracks.sum { |t| calculate_track_revenue(t, time_period) }
    }
  end
  
  private
  
  # Detect potential streaming fraud
  def detect_fraud?
    # Check streams per hour
    recent_streams = Stream.where(user: @user)
      .where("listened_at >= ?", 1.hour.ago)
      .count
    
    if recent_streams > MAX_STREAMS_PER_HOUR
      return true
    end
    
    # Check for rapid repeated streams of same track
    same_track_streams = Stream.where(user: @user, track: @track)
      .where("listened_at >= ?", 1.hour.ago)
      .count
    
    if same_track_streams > 10 # Max 10 plays of same track per hour
      return true
    end
    
    false
  end
  
  # Distribute revenue to artist and splits
  def distribute_revenue(stream, payout_rate)
    revenue = payout_rate
    
    # Check if there's a revenue split configured
    split = @track.album.revenue_split
    
    if split && split.recipients.present?
      # Distribute according to split percentages
      split.recipients.each_with_index do |recipient, index|
        percentage = split.percentages[index] || 0
        amount = revenue * (percentage / 100.0)
        
        # TODO: Actually transfer funds
        Rails.logger.info("Revenue split: #{amount} to #{recipient} (#{percentage}%) [#{stream.access_tier} tier]")
      end
    else
      # All revenue goes to artist
      Rails.logger.info("Revenue: #{revenue} to artist #{@artist.id} [#{stream.access_tier} tier, NFT: #{stream.nft_holder}]")
    end
    
    # TODO: Record revenue in database
    # Could create a Revenue model to track all payouts
  end
  
  # Check NFT ownership for album access
  def check_nft_ownership
    return false unless @album.respond_to?(:nft_collection?) && @album.nft_collection?
    # TODO: Implement MetaplexNftService.new.verify_album_access(@user.wallet_address, @album)
    # For now, return false until NFT system is implemented
    false
  end
  
  # Update platform-wide streaming metrics
  def update_platform_metrics
    metric = PlatformMetric.find_or_create_by(date: Date.today) do |m|
      m.daily_volume = 0
      m.fees_collected = 0
      m.tokens_burned = 0
      m.active_users = 0
      m.new_tokens = 0
      m.total_streams = 0
    end
    
    metric.increment!(:total_streams)
  end
  
  def self.calculate_track_revenue(track, time_period)
    eligible_streams = track.streams
      .where("duration >= ?", ELIGIBLE_STREAM_DURATION)
      .where("listened_at >= ?", time_period.ago)
      .count
    
    eligible_streams * PAYOUT_PER_STREAM
  end
end

