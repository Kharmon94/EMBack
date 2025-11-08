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
      
      # Shop & Product Management
      can :manage, ProductVariant, merch_item: { artist: { user_id: user.id } }
      can :read, Order do |order|
        # Artists can read orders for their products
        order.order_items.any? { |item| item.orderable.try(:artist)&.user_id == user.id }
      end
      can :update, Order do |order|
        # Artists can update status/tracking for their orders
        order.order_items.any? { |item| item.orderable.try(:artist)&.user_id == user.id }
      end
      can :read, OrderItem do |item|
        item.orderable.try(:artist)&.user_id == user.id
      end
      can :read, CartOrder, seller_id: user.artist&.id
      
      # Messaging (Artists can receive and respond)
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
      
      # Analytics & Tracking
      can :read, Stream, track: { album: { artist: { user_id: user.id } } }
      can :read, VideoView, video: { artist: { user_id: user.id } }
      can :read, MiniView, mini: { artist: { user_id: user.id } }
      can :read, ListeningHistory, track: { album: { artist: { user_id: user.id } } }
      can :read, ViewHistory, video: { artist: { user_id: user.id } }
      
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
    can :manage, Order, user_id: user.id
    can :read, OrderItem do |item|
      item.order.user_id == user.id
    end
    can :manage, CartOrder, user_id: user.id
    
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
    can :create, Share
    can :manage, Share, user_id: user.id
    
    # Shop features
    can :create, Review
    can :manage, Review, user_id: user.id
    can :create, ReviewVote
    can :manage, ReviewVote, user_id: user.id
    can :create, Wishlist
    can :manage, Wishlist, user_id: user.id
    can :manage, WishlistItem, wishlist: { user_id: user.id }
    can :create, RecentlyViewedItem
    can :manage, RecentlyViewedItem, user_id: user.id
    
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
    
    # Analytics & History (Own Data)
    can :manage, ListeningHistory, user_id: user.id
    can :manage, ViewHistory, user_id: user.id
    can :manage, SearchHistory, user_id: user.id
    can :manage, UserActivity, user_id: user.id
    
    # Pre-saves
    can :create, PreSave
    can :manage, PreSave, user_id: user.id
    
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
    can :read, Playlist
    can :read, Comment
    can :read, Like
  end
  
  def guest_permissions
    # Guests can only read public content
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
    can :read, PlatformToken
    can :read, PlatformMetric
    can :read, Playlist
    can :read, Comment
    can :read, Like
  end
end

