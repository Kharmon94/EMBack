class RecommendationService
  # Comprehensive recommendation engine for personalized content discovery
  
  def initialize(user = nil)
    @user = user
  end
  
  # === PERSONALIZED CONTENT SCORING ===
  
  # Score content based on user preferences and behavior
  def score_content(content, context = {})
    return base_popularity_score(content) unless @user
    
    score = 0.0
    
    # Weight factors
    weights = {
      listening_history: 0.25,
      follow_relationship: 0.20,
      genre_preference: 0.15,
      engagement_history: 0.15,
      recency: 0.10,
      popularity: 0.10,
      time_of_day: 0.05
    }
    
    score += listening_history_score(content) * weights[:listening_history]
    score += follow_relationship_score(content) * weights[:follow_relationship]
    score += genre_preference_score(content) * weights[:genre_preference]
    score += engagement_history_score(content) * weights[:engagement_history]
    score += recency_score(content) * weights[:recency]
    score += popularity_score(content) * weights[:popularity]
    score += time_of_day_score(content) * weights[:time_of_day]
    
    score
  end
  
  # === SIMILAR CONTENT ALGORITHM ===
  
  # Find similar tracks based on metadata
  def similar_tracks(track, limit = 20)
    return Track.none unless track
    
    # Get tracks from same artist (excluding this one)
    same_artist = Track.joins(:album)
                      .where(albums: { artist_id: track.album.artist_id })
                      .where.not(id: track.id)
                      .limit(5)
    
    # Get tracks from same album
    same_album = track.album.tracks.where.not(id: track.id).limit(3)
    
    # Get tracks with similar genre/mood (when implemented)
    # For now, use engagement patterns
    similar_engagement = Track.where(access_tier: track.access_tier)
                              .where.not(id: track.id)
                              .where.not(album_id: track.album_id)
                              .order(Arel.sql('RANDOM()'))
                              .limit(12)
    
    (same_artist.to_a + same_album.to_a + similar_engagement.to_a).uniq.take(limit)
  end
  
  # Find similar albums
  def similar_albums(album, limit = 12)
    return Album.none unless album
    
    # Same artist's albums
    same_artist = Album.where(artist_id: album.artist_id)
                      .where.not(id: album.id)
                      .order(release_date: :desc)
                      .limit(4)
    
    # Albums from similar engagement patterns
    similar = Album.where.not(id: album.id)
                  .where.not(artist_id: album.artist_id)
                  .order(Arel.sql('RANDOM()'))
                  .limit(limit - same_artist.count)
    
    (same_artist.to_a + similar.to_a).take(limit)
  end
  
  # Find similar videos
  def similar_videos(video, limit = 12)
    return Video.none unless video
    
    same_artist = Video.where(artist_id: video.artist_id)
                      .where.not(id: video.id)
                      .published
                      .limit(4)
    
    similar = Video.published
                  .where.not(id: video.id)
                  .where.not(artist_id: video.artist_id)
                  .where(access_tier: video.access_tier)
                  .order(views_count: :desc)
                  .limit(limit - same_artist.count)
    
    (same_artist.to_a + similar.to_a).take(limit)
  end
  
  # Find similar minis
  def similar_minis(mini, limit = 20)
    return Mini.none unless mini
    
    same_artist = Mini.where(artist_id: mini.artist_id)
                     .where.not(id: mini.id)
                     .published
                     .limit(5)
    
    similar = Mini.published
                 .where.not(id: mini.id)
                 .where.not(artist_id: mini.artist_id)
                 .order(Arel.sql('(views_count + likes_count * 2 + shares_count * 3) DESC'))
                 .limit(limit - same_artist.count)
    
    (same_artist.to_a + similar.to_a).take(limit)
  end
  
  # Find similar events
  def similar_events(event, limit = 10)
    return Event.none unless event
    
    same_artist = Event.where(artist_id: event.artist_id)
                      .where.not(id: event.id)
                      .upcoming
                      .limit(3)
    
    # Events in similar location
    nearby = Event.upcoming
                 .where.not(id: event.id)
                 .where.not(artist_id: event.artist_id)
                 .where("location ILIKE ?", "%#{extract_city(event.location)}%")
                 .limit(limit - same_artist.count)
    
    (same_artist.to_a + nearby.to_a).take(limit)
  end
  
  # === FOR YOU FEED GENERATION ===
  
  # Generate personalized track feed
  def tracks_for_you(limit = 50)
    return Track.joins(:album).order(Arel.sql('RANDOM()')).limit(limit) unless @user
    
    tracks = []
    
    # Tracks from followed artists (30%)
    followed_tracks = tracks_from_followed_artists(Track, limit * 0.3)
    tracks.concat(followed_tracks)
    
    # Tracks similar to user's liked tracks (25%)
    similar_to_liked = tracks_similar_to_liked(limit * 0.25)
    tracks.concat(similar_to_liked)
    
    # Trending tracks (20%)
    trending = Track.joins(:album)
                   .where('tracks.created_at > ?', 7.days.ago)
                   .order(Arel.sql('(SELECT COUNT(*) FROM streams WHERE streams.track_id = tracks.id AND streams.listened_at > NOW() - INTERVAL \'7 days\') DESC'))
                   .limit(limit * 0.20)
    tracks.concat(trending.to_a)
    
    # New releases (15%)
    new_releases = Track.joins(:album)
                       .where('tracks.created_at > ?', 14.days.ago)
                       .order(created_at: :desc)
                       .limit(limit * 0.15)
    tracks.concat(new_releases.to_a)
    
    # Random discovery (10%)
    discovery = Track.joins(:album)
                    .order(Arel.sql('RANDOM()'))
                    .limit(limit * 0.10)
    tracks.concat(discovery.to_a)
    
    tracks.uniq.take(limit)
  end
  
  # Generate personalized album feed
  def albums_for_you(limit = 30)
    return Album.order(Arel.sql('RANDOM()')).limit(limit) unless @user
    
    albums = []
    
    # Albums from followed artists
    followed = albums_from_followed_artists(limit * 0.4)
    albums.concat(followed)
    
    # New releases
    new_releases = Album.where('release_date > ?', 30.days.ago)
                       .order(release_date: :desc)
                       .limit(limit * 0.3)
    albums.concat(new_releases.to_a)
    
    # Popular albums
    popular = Album.order(Arel.sql('RANDOM()'))
                  .limit(limit * 0.3)
    albums.concat(popular.to_a)
    
    albums.uniq.take(limit)
  end
  
  # Generate personalized video feed
  def videos_for_you(limit = 20)
    return Video.published.order(Arel.sql('RANDOM()')).limit(limit) unless @user
    
    videos = []
    
    followed = videos_from_followed_artists(limit * 0.4)
    videos.concat(followed)
    
    trending = Video.published
                   .where('published_at > ?', 7.days.ago)
                   .order(views_count: :desc)
                   .limit(limit * 0.3)
    videos.concat(trending.to_a)
    
    recent = Video.published
                 .order(published_at: :desc)
                 .limit(limit * 0.3)
    videos.concat(recent.to_a)
    
    videos.uniq.take(limit)
  end
  
  # Enhanced mini feed (builds on existing Mini.for_you)
  def minis_for_you(limit = 50)
    Mini.for_you(@user).limit(limit)
  end
  
  # Generate personalized event recommendations
  def events_for_you(limit = 20)
    return Event.upcoming.order(start_time: :asc).limit(limit) unless @user
    
    events = []
    
    # Events from followed artists
    followed = events_from_followed_artists(limit * 0.5)
    events.concat(followed)
    
    # Upcoming events sorted by date
    upcoming = Event.upcoming
                   .order(start_time: :asc)
                   .limit(limit * 0.5)
    events.concat(upcoming.to_a)
    
    events.uniq.take(limit)
  end
  
  # Generate personalized livestream recommendations
  def livestreams_for_you(limit = 15)
    return Livestream.upcoming.order(start_time: :asc).limit(limit) unless @user
    
    streams = []
    
    # From followed artists
    followed = livestreams_from_followed_artists(limit * 0.6)
    streams.concat(followed)
    
    # Upcoming streams
    upcoming = Livestream.upcoming
                        .order(start_time: :asc)
                        .limit(limit * 0.4)
    streams.concat(upcoming.to_a)
    
    streams.uniq.take(limit)
  end
  
  # === COLLABORATIVE FILTERING ===
  
  # Find users with similar taste
  def similar_users(limit = 20)
    return User.none unless @user
    
    # Users who like similar tracks
    user_liked_track_ids = @user.likes.where(likeable_type: 'Track').pluck(:likeable_id)
    return User.none if user_liked_track_ids.empty?
    
    User.joins(:likes)
        .where(likes: { likeable_type: 'Track', likeable_id: user_liked_track_ids })
        .where.not(id: @user.id)
        .group('users.id')
        .order(Arel.sql('COUNT(likes.id) DESC'))
        .limit(limit)
  end
  
  # === TRENDING CALCULATION ===
  
  # Calculate trending score with decay
  def trending_score(content, time_window = 7.days)
    age_in_hours = ((Time.current - content.created_at) / 1.hour).to_f
    decay_factor = Math.exp(-age_in_hours / (time_window.to_f / 1.hour))
    
    engagement = case content
                when Track
                  Stream.where(track: content, listened_at: time_window.ago..).count
                when Video, Mini
                  content.views_count + (content.likes_count * 2)
                when Album
                  Stream.joins(:track).where(tracks: { album_id: content.id }, listened_at: time_window.ago..).count
                when Event
                  content.ticket_tiers.sum(:sold)
                else
                  0
                end
    
    engagement * decay_factor
  end
  
  private
  
  # === SCORING HELPERS ===
  
  def listening_history_score(content)
    return 0 unless @user
    
    case content
    when Track
      # Check if user has streamed tracks from this artist
      artist_id = content.album.artist_id
      recent_streams = Stream.joins(track: { album: :artist })
                            .where(user: @user, albums: { artist_id: artist_id })
                            .where('listened_at > ?', 30.days.ago)
                            .count
      [recent_streams / 10.0, 1.0].min
    when Album
      recent_streams = Stream.joins(track: :album)
                            .where(user: @user, albums: { artist_id: content.artist_id })
                            .where('listened_at > ?', 30.days.ago)
                            .count
      [recent_streams / 10.0, 1.0].min
    else
      0
    end
  end
  
  def follow_relationship_score(content)
    return 0 unless @user
    
    artist = case content
            when Track then content.album.artist
            when Album then content.artist
            when Video, Mini, Event, Livestream then content.artist
            else nil
            end
    
    return 0 unless artist
    Follow.exists?(user: @user, followable: artist) ? 1.0 : 0.0
  end
  
  def genre_preference_score(content)
    # TODO: Implement when Genre model is added
    0.5 # Neutral score for now
  end
  
  def engagement_history_score(content)
    return 0 unless @user
    
    # Check if user has liked or commented on similar content
    case content
    when Track
      artist_engagement = Like.where(user: @user, likeable_type: 'Track')
                             .joins("INNER JOIN tracks ON likes.likeable_id = tracks.id")
                             .joins("INNER JOIN albums ON tracks.album_id = albums.id")
                             .where(albums: { artist_id: content.album.artist_id })
                             .count
      [artist_engagement / 5.0, 1.0].min
    else
      0
    end
  end
  
  def recency_score(content)
    days_old = ((Time.current - content.created_at) / 1.day).to_i
    return 1.0 if days_old <= 7
    return 0.7 if days_old <= 30
    return 0.4 if days_old <= 90
    0.2
  end
  
  def popularity_score(content)
    case content
    when Track
      stream_count = Stream.where(track: content).count
      [stream_count / 1000.0, 1.0].min
    when Video, Mini
      [content.views_count / 10000.0, 1.0].min
    when Album
      [content.tracks.sum { |t| Stream.where(track: t).count } / 5000.0, 1.0].min
    else
      0.5
    end
  end
  
  def time_of_day_score(content)
    # TODO: Implement time-of-day preferences when user data is richer
    0.5 # Neutral score
  end
  
  def base_popularity_score(content)
    popularity_score(content)
  end
  
  # === CONTENT FETCHING HELPERS ===
  
  def tracks_from_followed_artists(model, limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    Track.joins(:album)
         .where(albums: { artist_id: followed_artist_ids })
         .order(created_at: :desc)
         .limit(limit)
         .to_a
  end
  
  def tracks_similar_to_liked(limit)
    return [] unless @user
    
    liked_track_ids = @user.likes.where(likeable_type: 'Track').pluck(:likeable_id).take(5)
    return [] if liked_track_ids.empty?
    
    similar = []
    liked_track_ids.each do |track_id|
      track = Track.find_by(id: track_id)
      similar.concat(similar_tracks(track, 5).to_a) if track
    end
    
    similar.uniq.take(limit)
  end
  
  def albums_from_followed_artists(limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    Album.where(artist_id: followed_artist_ids)
         .order(release_date: :desc)
         .limit(limit)
         .to_a
  end
  
  def videos_from_followed_artists(limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    Video.published
         .where(artist_id: followed_artist_ids)
         .order(published_at: :desc)
         .limit(limit)
         .to_a
  end
  
  def events_from_followed_artists(limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    Event.upcoming
         .where(artist_id: followed_artist_ids)
         .order(start_time: :asc)
         .limit(limit)
         .to_a
  end
  
  def livestreams_from_followed_artists(limit)
    return [] unless @user
    
    followed_artist_ids = @user.follows.where(followable_type: 'Artist').pluck(:followable_id)
    return [] if followed_artist_ids.empty?
    
    Livestream.upcoming
              .where(artist_id: followed_artist_ids)
              .order(start_time: :asc)
              .limit(limit)
              .to_a
  end
  
  def extract_city(location)
    return '' unless location
    # Simple extraction - take first part before comma
    location.split(',').first.strip
  end
end

