class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    
    if user.admin?
      # Admins can do everything
      can :manage, :all
    elsif user.artist?
      # Artists can manage their own content
      can :manage, Artist, user_id: user.id
      can :manage, ArtistToken, artist: { user_id: user.id }
      can :manage, Album, artist: { user_id: user.id }
      can :manage, Track, album: { artist: { user_id: user.id } }
      can :manage, Video, artist: { user_id: user.id }
      can :manage, Mini, artist: { user_id: user.id }
      can :manage, Event, artist: { user_id: user.id }
      can :manage, TicketTier, event: { artist: { user_id: user.id } }
      can :manage, Livestream, artist: { user_id: user.id }
      can :manage, MerchItem, artist: { user_id: user.id }
      can :manage, FanPass, artist: { user_id: user.id }
      can :manage, Airdrop, artist: { user_id: user.id }
      
      # Artists can read everything users can
      artist_read_permissions(user)
    else
      # Regular users (fans)
      fan_permissions(user)
    end
    
    # Guest permissions (not logged in)
    guest_permissions
  end
  
  private
  
  def fan_permissions(user)
    # Can manage own content
    can :manage, Playlist, user_id: user.id
    can :manage, Follow, user_id: user.id
    can :create, Report
    can :manage, Report, user_id: user.id
    
    # Can purchase and own
    can :create, Purchase, user_id: user.id
    can :create, Trade, user_id: user.id
    can :read, Purchase, user_id: user.id
    can :read, Trade, user_id: user.id
    can :read, Ticket, user_id: user.id
    can :read, Order, user_id: user.id
    
    # Can purchase and own fan pass NFTs
    can :create, FanPassNft
    can :read, FanPassNft, user_id: user.id
    
    # Can interact with streams
    can :create, Stream
    can :read, Stream, user_id: user.id
    
    # Can watch videos
    can :create, VideoView
    can :read, VideoView, user_id: user.id
    
    # Can watch minis
    can :create, MiniView
    can :read, MiniView, user_id: user.id
    
    # Can participate in livestreams
    can :create, StreamMessage
    can :read, StreamMessage
    
    # Social features
    can :create, Comment
    can :manage, Comment, user_id: user.id  # Can edit/delete own comments
    can :create, Like
    can :destroy, Like, user_id: user.id  # Can unlike
    can :read, Notification, user_id: user.id
    can :manage, Notification, user_id: user.id
    
    # Shop features
    can :create, Review
    can :manage, Review, user_id: user.id
    can :create, ReviewVote
    can :manage, ReviewVote, user_id: user.id
    can :create, Wishlist
    can :manage, Wishlist, user_id: user.id
    can :manage, WishlistItem, wishlist: { user_id: user.id }
    can :create, RecentlyViewedItem
    
    # Direct Messaging
    can :create, Conversation
    can :read, Conversation do |conversation|
      conversation.users.include?(user)
    end
    can :manage, ConversationParticipant, user_id: user.id
    can :create, DirectMessage do |message|
      message.conversation.users.include?(user)
    end
    can :read, DirectMessage do |message|
      message.conversation.users.include?(user)
    end
    
    # Read permissions
    artist_read_permissions(user)
  end
  
  def artist_read_permissions(user)
    # Can read public content
    can :read, Artist
    can :read, ArtistToken
    can :read, Album
    can :read, Track
    can :read, Video
    can :read, Mini
    can :read, Event
    can :read, TicketTier
    can :read, Livestream
    can :read, MerchItem
    can :read, ProductCategory
    can :read, ProductTag
    can :read, ProductVariant
    can :read, Review
    can :read, FanPass
    can :read, LiquidityPool
    can :read, PlatformToken
    can :read, PlatformMetric
  end
  
  def guest_permissions
    # Guests can only read public content
    can :read, Artist
    can :read, Album
    can :read, Track
    can :read, Video
    can :read, Mini
    can :read, Event
    can :read, TicketTier
    can :read, MerchItem
    can :read, ProductCategory
    can :read, ProductTag
    can :read, ProductVariant
    can :read, Review
    can :read, PlatformToken
    can :read, PlatformMetric
  end
end

