class UserStatsService
  def initialize(user, timeframe = :all_time)
    @user = user
    @timeframe = timeframe
    @start_time, @end_time = calculate_timeframe(timeframe)
  end
  
  # === LISTENING STATS ===
  
  def listening_stats
    {
      total_time: total_listening_time,
      total_tracks: total_tracks_played,
      top_artists: top_artists(10),
      top_tracks: top_tracks(10),
      top_albums: top_albums(10),
      top_genres: top_genres(10),
      listening_patterns: listening_patterns,
      discovery_stats: discovery_stats
    }
  end
  
  # === VIDEO/MINI STATS ===
  
  def viewing_stats
    {
      total_watch_time: total_watch_time,
      total_videos: total_videos_watched,
      total_minis: total_minis_watched,
      top_video_artists: top_video_artists(10),
      completion_rate: view_completion_rate
    }
  end
  
  # === ENGAGEMENT STATS ===
  
  def engagement_stats
    {
      likes_given: likes_count,
      comments_made: comments_count,
      playlists_created: playlists_count,
      shares_made: shares_count,
      artists_followed: followed_artists_count,
      events_attended: events_attended_count
    }
  end
  
  # === WRAPPED-STYLE SUMMARY ===
  
  def wrapped_summary
    {
      timeframe: @timeframe,
      start_date: @start_time,
      end_date: @end_time,
      listening: listening_stats,
      viewing: viewing_stats,
      engagement: engagement_stats,
      highlights: generate_highlights,
      personality: generate_personality_insights
    }
  end
  
  private
  
  # === TIMEFRAME CALCULATION ===
  
  def calculate_timeframe(timeframe)
    case timeframe
    when :last_7_days
      [7.days.ago, Time.current]
    when :last_30_days
      [30.days.ago, Time.current]
    when :last_year
      [1.year.ago, Time.current]
    when :this_year
      [Time.current.beginning_of_year, Time.current]
    when :all_time
      [@user.created_at, Time.current]
    else
      # Custom range
      [timeframe[:start], timeframe[:end]]
    end
  end
  
  def scoped_listening_history
    if @start_time && @end_time
      @user.listening_histories.in_timeframe(@start_time, @end_time)
    else
      @user.listening_histories
    end
  end
  
  def scoped_view_history
    if @start_time && @end_time
      @user.view_histories.in_timeframe(@start_time, @end_time)
    else
      @user.view_histories
    end
  end
  
  # === LISTENING CALCULATIONS ===
  
  def total_listening_time
    scoped_listening_history.sum(:duration_played)
  end
  
  def total_tracks_played
    scoped_listening_history.select(:track_id).distinct.count
  end
  
  def top_artists(limit = 10)
    scoped_listening_history
      .joins(track: { album: :artist })
      .group('artists.id', 'artists.name')
      .select('artists.id, artists.name, COUNT(*) as play_count, SUM(listening_histories.duration_played) as total_time')
      .order('play_count DESC')
      .limit(limit)
      .map do |result|
        {
          id: result.id,
          name: result.name,
          play_count: result.play_count,
          total_time: result.total_time
        }
      end
  end
  
  def top_tracks(limit = 10)
    scoped_listening_history
      .joins(:track)
      .group('tracks.id', 'tracks.title')
      .select('tracks.id, tracks.title, COUNT(*) as play_count, SUM(listening_histories.duration_played) as total_time')
      .order('play_count DESC')
      .limit(limit)
      .map do |result|
        {
          id: result.id,
          title: result.title,
          play_count: result.play_count,
          total_time: result.total_time
        }
      end
  end
  
  def top_albums(limit = 10)
    scoped_listening_history
      .joins(track: :album)
      .group('albums.id', 'albums.title')
      .select('albums.id, albums.title, COUNT(DISTINCT tracks.id) as unique_tracks_played, COUNT(*) as play_count')
      .order('play_count DESC')
      .limit(limit)
      .map do |result|
        {
          id: result.id,
          title: result.title,
          unique_tracks_played: result.unique_tracks_played,
          play_count: result.play_count
        }
      end
  end
  
  def top_genres(limit = 10)
    # TODO: Implement when Genre model is added
    []
  end
  
  def listening_patterns
    # Analyze when user listens most
    patterns = scoped_listening_history
                .group("EXTRACT(HOUR FROM created_at)")
                .count
    
    {
      hourly_distribution: patterns,
      peak_hour: patterns.max_by { |k, v| v }&.first,
      weekday_distribution: weekday_listening_distribution
    }
  end
  
  def weekday_listening_distribution
    scoped_listening_history
      .group("EXTRACT(DOW FROM created_at)")
      .count
  end
  
  def discovery_stats
    {
      new_artists_discovered: new_artists_discovered_count,
      new_tracks_discovered: new_tracks_discovered_count
    }
  end
  
  def new_artists_discovered_count
    # Artists listened to for first time in this period
    artist_ids_this_period = scoped_listening_history
                              .joins(track: { album: :artist })
                              .select('artists.id')
                              .distinct
                              .pluck('artists.id')
    
    artist_ids_before_period = @user.listening_histories
                                .where('created_at < ?', @start_time)
                                .joins(track: { album: :artist })
                                .select('artists.id')
                                .distinct
                                .pluck('artists.id')
    
    (artist_ids_this_period - artist_ids_before_period).count
  end
  
  def new_tracks_discovered_count
    track_ids_this_period = scoped_listening_history.select(:track_id).distinct.pluck(:track_id)
    track_ids_before_period = @user.listening_histories
                               .where('created_at < ?', @start_time)
                               .select(:track_id)
                               .distinct
                               .pluck(:track_id)
    
    (track_ids_this_period - track_ids_before_period).count
  end
  
  # === VIEWING CALCULATIONS ===
  
  def total_watch_time
    scoped_view_history.sum(:duration_watched)
  end
  
  def total_videos_watched
    scoped_view_history.where(viewable_type: 'Video').select(:viewable_id).distinct.count
  end
  
  def total_minis_watched
    scoped_view_history.where(viewable_type: 'Mini').select(:viewable_id).distinct.count
  end
  
  def top_video_artists(limit = 10)
    scoped_view_history
      .where(viewable_type: ['Video', 'Mini'])
      .joins("INNER JOIN videos ON view_histories.viewable_id = videos.id AND view_histories.viewable_type = 'Video' 
              UNION ALL 
              SELECT view_histories.*, minis.artist_id FROM view_histories 
              INNER JOIN minis ON view_histories.viewable_id = minis.id AND view_histories.viewable_type = 'Mini'")
      .group('artist_id')
      .count
      .sort_by { |k, v| -v }
      .take(limit)
  end
  
  def view_completion_rate
    total_views = scoped_view_history.count
    return 0 if total_views.zero?
    
    completed_views = scoped_view_history.completed_only.count
    ((completed_views.to_f / total_views) * 100).round(2)
  end
  
  # === ENGAGEMENT CALCULATIONS ===
  
  def likes_count
    scope = @user.likes
    scope = scope.where(created_at: @start_time..@end_time) if @start_time && @end_time
    scope.count
  end
  
  def comments_count
    scope = @user.comments
    scope = scope.where(created_at: @start_time..@end_time) if @start_time && @end_time
    scope.count
  end
  
  def playlists_count
    scope = @user.playlists
    scope = scope.where(created_at: @start_time..@end_time) if @start_time && @end_time
    scope.count
  end
  
  def shares_count
    scope = @user.shares
    scope = scope.where(created_at: @start_time..@end_time) if @start_time && @end_time
    scope.count
  end
  
  def followed_artists_count
    scope = @user.follows.where(followable_type: 'Artist')
    scope = scope.where(created_at: @start_time..@end_time) if @start_time && @end_time
    scope.count
  end
  
  def events_attended_count
    scope = @user.tickets.joins(:ticket_tier)
    scope = scope.where('tickets.created_at >= ? AND tickets.created_at <= ?', @start_time, @end_time) if @start_time && @end_time
    scope.count
  end
  
  # === HIGHLIGHTS GENERATION ===
  
  def generate_highlights
    highlights = []
    
    # Top artist highlight
    if top_artist = top_artists(1).first
      total_minutes = (top_artist[:total_time] / 60.0).round
      highlights << {
        type: 'top_artist',
        message: "You listened to #{top_artist[:name]} for #{total_minutes} minutes!",
        data: top_artist
      }
    end
    
    # Total listening time highlight
    total_hours = (total_listening_time / 3600.0).round(1)
    if total_hours > 0
      highlights << {
        type: 'total_time',
        message: "You listened to #{total_hours} hours of music!",
        data: { hours: total_hours }
      }
    end
    
    # Discovery highlight
    new_artists = new_artists_discovered_count
    if new_artists > 0
      highlights << {
        type: 'discovery',
        message: "You discovered #{new_artists} new artists!",
        data: { count: new_artists }
      }
    end
    
    # Engagement highlight
    total_engagement = likes_count + comments_count + shares_count
    if total_engagement > 50
      highlights << {
        type: 'engagement',
        message: "You were super engaged with #{total_engagement} likes, comments, and shares!",
        data: { count: total_engagement }
      }
    end
    
    highlights
  end
  
  # === PERSONALITY INSIGHTS ===
  
  def generate_personality_insights
    insights = []
    
    # Listening time insights
    total_hours = total_listening_time / 3600.0
    case total_hours
    when 0..10
      insights << { category: 'listener_type', value: 'casual', label: 'Casual Listener' }
    when 10..50
      insights << { category: 'listener_type', value: 'regular', label: 'Regular Listener' }
    when 50..200
      insights << { category: 'listener_type', value: 'dedicated', label: 'Dedicated Fan' }
    else
      insights << { category: 'listener_type', value: 'superfan', label: 'Superfan' }
    end
    
    # Discovery insights
    new_artists_ratio = new_artists_discovered_count.to_f / [top_artists.count, 1].max
    if new_artists_ratio > 0.5
      insights << { category: 'discovery', value: 'explorer', label: 'Music Explorer' }
    else
      insights << { category: 'discovery', value: 'loyal', label: 'Loyal Fan' }
    end
    
    # Engagement insights
    if shares_count > likes_count * 0.3
      insights << { category: 'engagement', value: 'sharer', label: 'Music Sharer' }
    end
    
    if playlists_count > 5
      insights << { category: 'engagement', value: 'curator', label: 'Playlist Curator' }
    end
    
    insights
  end
end

