class DiscoveryService
  # Cross-content discovery and smart recommendations
  
  def initialize(user = nil)
    @user = user
    @recommendation_service = RecommendationService.new(user)
  end
  
  # === RELATED CONTENT ACROSS TYPES ===
  
  # Get related content for any item
  def related_content(item, limit = 10)
    case item
    when Track
      related_to_track(item, limit)
    when Album
      related_to_album(item, limit)
    when Video
      related_to_video(item, limit)
    when Mini
      related_to_mini(item, limit)
    when Event
      related_to_event(item, limit)
    when Artist
      related_to_artist(item, limit)
    else
      []
    end
  end
  
  # === UNIFIED HOME FEED ===
  
  # Generate mixed content feed
  def home_feed(limit = 50)
    return guest_feed(limit) unless @user
    
    feed_items = []
    
    # Distribution:
    # 30% - New releases from followed artists
    # 25% - Trending content
    # 20% - Personalized recommendations
    # 15% - Friend activity
    # 10% - Upcoming events from followed artists
    
    # New releases (30%)
    feed_items.concat(new_releases_from_follows(limit * 0.30))
    
    # Trending (25%)
    feed_items.concat(trending_content(limit * 0.25))
    
    # Recommendations (20%)
    feed_items.concat(personalized_recommendations(limit * 0.20))
    
    # Friend activity (15%)
    feed_items.concat(friend_activity(limit * 0.15))
    
    # Events (10%)
    feed_items.concat(upcoming_events_from_follows(limit * 0.10))
    
    # Shuffle and limit
    feed_items.shuffle.take(limit)
  end
  
  # === SMART CROSS-CONTENT SUGGESTIONS ===
  
  # "Because you liked X" recommendations
  def because_you_liked(item, limit = 10)
    artist = extract_artist(item)
    return [] unless artist
    
    suggestions = []
    
    # Other content from same artist
    suggestions.concat(artist.albums.released.limit(2).to_a)
    suggestions.concat(artist.videos.published.limit(2).to_a)
    suggestions.concat(artist.events.upcoming.limit(2).to_a)
    suggestions.concat(artist.minis.published.limit(2).to_a)
    
    # Similar artists' content
    # TODO: Implement similar artists algorithm
    
    suggestions.take(limit)
  end
  
  # === CONTENT-SPECIFIC RELATED METHODS ===
  
  private
  
  def related_to_track(track, limit)
    artist = track.album.artist
    items = []
    
    # Same album tracks
    items.concat(track.album.tracks.where.not(id: track.id).limit(3).to_a)
    
    # Same artist albums
    items.concat(artist.albums.where.not(id: track.album_id).limit(2).to_a)
    
    # Artist events
    items.concat(artist.events.upcoming.limit(2).to_a)
    
    # Artist videos/minis
    items.concat(artist.videos.published.limit(1).to_a)
    items.concat(artist.minis.published.limit(2).to_a)
    
    items.take(limit).map { |i| format_feed_item(i) }
  end
  
  def related_to_album(album, limit)
    artist = album.artist
    items = []
    
    # Other artist albums
    items.concat(artist.albums.where.not(id: album.id).released.limit(3).to_a)
    
    # Artist events
    items.concat(artist.events.upcoming.limit(2).to_a)
    
    # Artist videos
    items.concat(artist.videos.published.limit(2).to_a)
    
    # Similar albums
    items.concat(@recommendation_service.similar_albums(album, 3).to_a)
    
    items.take(limit).map { |i| format_feed_item(i) }
  end
  
  def related_to_video(video, limit)
    artist = video.artist
    items = []
    
    # Same artist videos
    items.concat(artist.videos.published.where.not(id: video.id).limit(4).to_a)
    
    # Artist albums
    items.concat(artist.albums.released.limit(2).to_a)
    
    # Artist events
    items.concat(artist.events.upcoming.limit(2).to_a)
    
    # Similar videos
    items.concat(@recommendation_service.similar_videos(video, 2).to_a)
    
    items.take(limit).map { |i| format_feed_item(i) }
  end
  
  def related_to_mini(mini, limit)
    artist = mini.artist
    items = []
    
    # Same artist minis
    items.concat(artist.minis.published.where.not(id: mini.id).limit(6).to_a)
    
    # Similar minis
    items.concat(@recommendation_service.similar_minis(mini, 4).to_a)
    
    items.take(limit).map { |i| format_feed_item(i) }
  end
  
  def related_to_event(event, limit)
    artist = event.artist
    items = []
    
    # Same artist events
    items.concat(artist.events.upcoming.where.not(id: event.id).limit(3).to_a)
    
    # Artist music
    items.concat(artist.albums.released.limit(2).to_a)
    
    # Artist videos
    items.concat(artist.videos.published.limit(2).to_a)
    
    # Similar events
    items.concat(@recommendation_service.similar_events(event, 3).to_a)
    
    items.take(limit).map { |i| format_feed_item(i) }
  end
  
  def related_to_artist(artist, limit)
    items = []
    
    # Latest releases
    items.concat(artist.albums.released.order(release_date: :desc).limit(3).to_a)
    
    # Popular videos
    items.concat(artist.videos.published.popular.limit(2).to_a)
    
    # Upcoming events
    items.concat(artist.events.upcoming.limit(2).to_a)
    
    # Recent minis
    items.concat(artist.minis.published.recent.limit(3).to_a)
    
    items.take(limit).map { |i| format_feed_item(i) }
  end
  
  # === FEED GENERATION HELPERS ===
  
  def new_releases_from_follows(limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    items = []
    
    # New albums
    items.concat(
      Album.where(artist_id: followed_artist_ids)
           .where('release_date > ?', 30.days.ago)
           .order(release_date: :desc)
           .limit(limit * 0.5)
           .to_a
    )
    
    # New videos
    items.concat(
      Video.published
           .where(artist_id: followed_artist_ids)
           .where('published_at > ?', 7.days.ago)
           .order(published_at: :desc)
           .limit(limit * 0.3)
           .to_a
    )
    
    # New minis
    items.concat(
      Mini.published
          .where(artist_id: followed_artist_ids)
          .where('published_at > ?', 3.days.ago)
          .order(published_at: :desc)
          .limit(limit * 0.2)
          .to_a
    )
    
    items.shuffle.take(limit).map { |i| format_feed_item(i, context: 'new_from_following') }
  end
  
  def trending_content(limit)
    items = []
    
    # Trending tracks
    trending_tracks = Track.joins(:album)
                          .joins('LEFT JOIN streams ON streams.track_id = tracks.id AND streams.listened_at > NOW() - INTERVAL \'7 days\'')
                          .group('tracks.id')
                          .order('COUNT(streams.id) DESC')
                          .limit(limit * 0.4)
    items.concat(trending_tracks.to_a)
    
    # Trending videos
    items.concat(Video.trending.limit(limit * 0.3).to_a)
    
    # Trending minis
    items.concat(Mini.trending.limit(limit * 0.3).to_a)
    
    items.shuffle.take(limit).map { |i| format_feed_item(i, context: 'trending') }
  end
  
  def personalized_recommendations(limit)
    return [] unless @user
    
    items = []
    
    # Recommended tracks
    items.concat(@recommendation_service.tracks_for_you(limit * 0.5).to_a)
    
    # Recommended videos
    items.concat(@recommendation_service.videos_for_you(limit * 0.3).to_a)
    
    # Recommended minis
    items.concat(@recommendation_service.minis_for_you(limit * 0.2).to_a)
    
    items.shuffle.take(limit).map { |i| format_feed_item(i, context: 'recommended') }
  end
  
  def friend_activity(limit)
    return [] unless @user
    
    # Get friend user IDs
    friend_ids = @user.follows.where(followable_type: 'User', friendship: true).pluck(:followable_id)
    return [] if friend_ids.empty?
    
    # Recent friend activities
    activities = UserActivity.where(user_id: friend_ids)
                            .where('created_at > ?', 24.hours.ago)
                            .includes(:activityable, :user)
                            .recent
                            .limit(limit)
    
    activities.map do |activity|
      format_feed_item(activity.activityable, context: 'friend_activity', friend: activity.user, activity_type: activity.activity_type)
    end
  end
  
  def upcoming_events_from_follows(limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    Event.upcoming
         .where(artist_id: followed_artist_ids)
         .order(start_time: :asc)
         .limit(limit)
         .map { |e| format_feed_item(e, context: 'upcoming_event') }
  end
  
  def guest_feed(limit)
    # For non-logged-in users, show popular content
    items = []
    
    # Popular albums
    items.concat(Album.released.order(Arel.sql('RANDOM()')).limit(limit * 0.4).to_a)
    
    # Popular videos
    items.concat(Video.popular.limit(limit * 0.3).to_a)
    
    # Trending minis
    items.concat(Mini.trending.limit(limit * 0.3).to_a)
    
    items.shuffle.take(limit).map { |i| format_feed_item(i, context: 'popular') }
  end
  
  # === HELPERS ===
  
  def extract_artist(item)
    case item
    when Track then item.album.artist
    when Album then item.artist
    when Video, Mini, Event, Livestream then item.artist
    when Artist then item
    else nil
    end
  end
  
  def format_feed_item(item, context: nil, friend: nil, activity_type: nil)
    {
      id: item.id,
      type: item.class.name.underscore,
      content: item,
      context: context,
      friend: friend ? { id: friend.id, email: friend.email } : nil,
      activity_type: activity_type,
      timestamp: item.created_at || item.updated_at
    }
  end
end

