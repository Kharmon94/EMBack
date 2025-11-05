# Backend Documentation - EncryptedMedia

> **Rails 8 API powering the Web3 Social Music Platform**

---

## 📖 Table of Contents

1. [Setup](#setup)
2. [Architecture](#architecture)
3. [Database Schema](#database-schema)
4. [API Endpoints](#api-endpoints)
5. [Key Features](#key-features)
6. [Social Features](#social-features)
7. [Testing](#testing)
8. [Deployment](#deployment)

---

## 🚀 Setup

### Prerequisites
- Ruby 3.3+
- PostgreSQL 15+
- Redis 7+
- Bundler 2.5+

### Installation

```bash
# Install dependencies
bundle install

# Create database and run migrations
rails db:create db:migrate

# Seed with test data
rails db:seed

# Start server
rails server -p 5000
```

### Environment Variables

Create `.env` file:
```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/backend_development
REDIS_URL=redis://localhost:6379/0
SOLANA_RPC_URL=https://api.devnet.solana.com
JWT_SECRET_KEY=your_secret_key_here
RTMP_HOST=localhost
RTMP_PORT=1935
HLS_HOST=localhost
HLS_PORT=8000
```

---

## 🏗️ Architecture

### MVC Structure

```
app/
├── channels/          # ActionCable (WebSocket) channels
├── controllers/
│   └── api/v1/       # Versioned REST API
├── models/           # ActiveRecord models
├── services/         # Business logic layer
└── jobs/             # Sidekiq background jobs
```

### Service Objects

We use service objects for complex business logic:

- **BondingCurveService**: Token pricing and trading
- **StreamingService**: Music streaming access control
- **FanPassService**: NFT minting and dividend distribution
- **StreamingRtmpService**: RTMP server integration
- **RecommendationService**: Social discovery algorithms

### Background Jobs

- `GraduationJob`: Token graduation to DEX
- `DividendDistributionJob`: Monthly fan pass payouts (planned)
- `NotificationJob`: Send notifications (planned)

---

## 💾 Database Schema

### Core Tables

**users**
- Authentication (Devise + JWT)
- Social profile (display_name, bio, avatar_url)
- Social counts (followers_count, following_count)

**artists**
- One per user (has_one relationship)
- Profile (name, bio, banner, verified)
- Social links (Twitter, Instagram, website)

**artist_tokens**
- One per artist (enforced policy)
- Bonding curve parameters
- Current price and market cap

### Content Tables

**albums & tracks**
- Music content
- Access tiers (free, preview, NFT-gated)
- Likes and comments (polymorphic)

**events & ticket_tiers**
- Event management
- Multi-tier ticketing
- NFT tickets

**livestreams**
- RTMP streaming
- Stream keys and URLs
- Viewer tracking

**fan_passes, fan_pass_nfts, dividends**
- NFT collections
- Revenue sharing
- Dividend tracking

### Social Tables

**follows**
- User → Artist relationships
- Counter caches

**notifications**
- Real-time alerts
- Notification types (new_album, stream_live, etc.)

**comments**
- Polymorphic (albums, tracks, events, livestreams, fan_passes)
- Nested replies support
- Like counts

**likes**
- Polymorphic (all content types + comments)
- Unique per user per item

---

## 📡 API Endpoints

### Authentication
```
POST   /api/v1/auth/sign_up      # Register with wallet
POST   /api/v1/auth/sign_in      # Login with wallet
DELETE /api/v1/auth/sign_out     # Logout
```

### Artists
```
GET    /api/v1/artists           # Browse artists
GET    /api/v1/artists/:id       # Artist details
GET    /api/v1/artists/:id/profile  # ⭐ Comprehensive profile (showcase)
PATCH  /api/v1/artists/:id       # Update artist profile
POST   /api/v1/artists/:id/follow    # Follow artist
DELETE /api/v1/artists/:id/follow    # Unfollow artist
```

### Music
```
GET    /api/v1/albums            # Browse albums
GET    /api/v1/albums/:id        # Album details
POST   /api/v1/albums            # Create album (artist only)
GET    /api/v1/tracks/:id/stream # Stream track (access control)
PATCH  /api/v1/tracks/:id/update_access  # Update access tier
```

### Events
```
GET    /api/v1/events            # Browse events
GET    /api/v1/events/:id        # Event details
POST   /api/v1/events/:id/purchase_ticket  # Buy ticket
POST   /api/v1/tickets/:id/checkin  # Check-in with QR
```

### Livestreams
```
GET    /api/v1/livestreams       # Browse streams (live/upcoming)
POST   /api/v1/livestreams       # Create stream → get RTMP creds
POST   /api/v1/livestreams/:id/start   # Mark as live
POST   /api/v1/livestreams/:id/stop    # End stream
GET    /api/v1/livestreams/:id/status  # Check status
```

### Fan Passes
```
GET    /api/v1/fan_passes        # Browse fan passes
POST   /api/v1/fan_passes/:id/purchase  # Mint NFT
GET    /api/v1/fan_passes/:id/holders   # List holders
POST   /api/v1/fan_passes/:id/distribute_dividends  # Pay dividends
```

### Social
```
GET    /api/v1/notifications     # User notifications
POST   /api/v1/notifications/mark_all_as_read
POST   /api/v1/:resource/:id/like      # Like content
DELETE /api/v1/:resource/:id/like      # Unlike content
GET    /api/v1/:resource/:id/comments  # Get comments
POST   /api/v1/:resource/:id/comments  # Post comment
```

---

## 🎯 Key Features

### 1. Artist-Controlled Track Access

Artists have full per-track control over streaming access.

**Access Tiers:**
- 🌍 **Free**: Full streaming for everyone
- 👀 **Preview**: 30-second clips only
- 🔒 **NFT Required**: Exclusive to NFT holders

**Royalty Rates:**
- Free streams: $0.0005/stream
- Preview plays: $0.0001/play
- NFT holder streams: $0.001/stream (2x premium!)

**Implementation:**
```ruby
class StreamingService
  def check_access(user, track)
    # NFT holders bypass all restrictions
    return premium_access if user_owns_nft?(user, track)
    
    # Check track's access setting
    case track.access_tier
    when 'free' then { allowed: true, duration: 'unlimited' }
    when 'preview_only' then { allowed: true, duration: 30 }
    when 'nft_required' then { allowed: false }
    end
  end
end
```

**Artist Dashboard:** `/artist/albums/:id/tracks`

### 2. Fan Pass Dividend NFT System

Limited edition NFTs that grant holders perks and revenue share.

**Features:**
- Max supply: 1-10,000 NFTs
- Dividend percentage: 0-50% of artist revenue
- Distribution: Paid, airdrop, or hybrid
- Revenue sources: Streaming, sales, merch, events, tokens

**Revenue Model Example:**
```
Artist earns 10 SOL/month with 20% dividend:

Total Revenue:        10.00 SOL
Dividend Pool (20%):   2.00 SOL
Artist Keeps (80%):    8.00 SOL

Per Holder (100 NFTs): 0.02 SOL/month
Annual per holder:     0.24 SOL/year
```

**Platform Fees:**
- Initial sale: 10%
- Secondary sales: 5% royalty
- Dev cut: 20% of fees

**Implementation:**
```ruby
class FanPassService
  def distribute_dividends(period_start, period_end, revenue_by_source)
    total_pool = revenue_by_source.sum * (dividend_percentage / 100.0)
    per_holder = total_pool / active_holders
    
    # Create dividend records for batch processing
    active_nfts.each do |nft|
      nft.dividends.create!(
        amount: per_holder,
        period_start: period_start,
        period_end: period_end
      )
    end
  end
end
```

### 3. RTMP Livestreaming

Custom RTMP server for artist livestreaming.

**Flow:**
```
Artist (OBS) → RTMP Server → HLS Transcode → Fans (Browser)
               ↓
         Rails Backend
         (Validation & Tracking)
```

**Components:**
- **RTMP Server**: Node.js with node-media-server
- **FFmpeg**: Transcodes RTMP to HLS
- **Rails API**: Validates stream keys, tracks viewers
- **HLS.js Player**: Browser playback

**Setup:**
```bash
cd streaming_server
npm install
npm start  # Port 1935 (RTMP), 8000 (HLS)
```

**Stream Key Security:**
- Generated with `SecureRandom.hex(16)` (256-bit)
- Validated before accepting connection
- Never exposed in plain text

### 4. One Token Per Wallet

Each wallet can only create ONE artist token.

**Enforcement:**
1. Database: `User.has_one :artist.has_one :artist_token`
2. Model validation: Check wallet hasn't created token
3. Controller check: Defense-in-depth before creation

**Why:**
- Prevents spam and Sybil attacks
- Ensures authenticity
- Maintains market integrity
- Simplifies user experience

**Implementation:**
```ruby
# In ArtistTokensController
if ArtistToken.joins(artist: :user)
              .exists?(users: { wallet_address: current_user.wallet_address })
  return render json: { 
    error: 'This wallet has already created a token' 
  }, status: :forbidden
end
```

---

## 🌐 Social Features

### Follow System

**Models:**
```ruby
class Follow < ApplicationRecord
  belongs_to :user
  belongs_to :artist
end
```

**Features:**
- Users follow artists
- Counter caches for performance
- Follow notifications sent automatically
- Following feed for content discovery

**Endpoints:**
```
POST   /api/v1/artists/:id/follow
DELETE /api/v1/artists/:id/follow
GET    /api/v1/users/:id/following
GET    /api/v1/artists/:id/followers
```

### Notifications

**Types:**
- `new_album`: Artist released new music
- `new_event`: Artist announced event
- `new_livestream`: Stream scheduled
- `stream_live`: Artist went live NOW
- `new_follower`: Someone followed you
- `new_comment`: Comment on your content
- `new_like`: Someone liked your content
- `dividend_payment`: Fan pass dividend received

**Real-time Delivery:**
- ActionCable channel per user
- Browser notifications (planned)
- Email digests (planned)

**Implementation:**
```ruby
# Create notification
notification = Notification.create_album_notification(user, album)

# Broadcast real-time
NotificationChannel.broadcast_to_user(user, notification)
```

### Comments & Likes

**Polymorphic Associations:**
Comments and likes work on:
- Albums
- Tracks
- Events
- Livestreams
- Fan Passes
- Comments (nested)

**Features:**
- Nested replies (1 level)
- Like counts (cached)
- Owner notifications
- Moderation tools

**Endpoints:**
```
GET    /api/v1/:resource/:id/comments
POST   /api/v1/:resource/:id/comments
POST   /api/v1/:resource/:id/like
DELETE /api/v1/:resource/:id/like
```

### Activity Feeds

Personalized feed of activity from followed artists.

**Feed Items:**
- New album releases
- Upcoming events
- Livestream announcements
- Fan pass launches

**Implementation:**
```ruby
def feed
  followed_artists = current_user.follows.pluck(:artist_id)
  
  activities = []
  activities += Album.where(artist_id: followed_artists)
                    .where('created_at > ?', 30.days.ago)
  activities += Event.where(artist_id: followed_artists)
                    .upcoming
  # ... aggregate and sort
end
```

---

## 🧪 Testing

### Running Tests

```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/models/artist_token_spec.rb

# With coverage
COVERAGE=true bundle exec rspec
```

### Test Data

```bash
# Reset and seed
rails db:reset

# Custom seed
rails db:seed
```

### Manual API Testing

```bash
# Get artist profile
curl http://localhost:5000/api/v1/artists/1/profile

# Create notification
curl -X POST http://localhost:5000/api/v1/notifications \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"notification":{"title":"Test","message":"Hello"}}'

# Post comment
curl -X POST http://localhost:5000/api/v1/albums/1/comments \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"comment":{"content":"Great album!"}}'
```

---

## 🚢 Deployment

### Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link project
railway link

# Deploy
railway up
```

### Environment Setup

Required variables:
```env
RAILS_MASTER_KEY=<your_master_key>
DATABASE_URL=<postgres_url>
REDIS_URL=<redis_url>
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
```

### Migrations

```bash
# Run on deploy
rails db:migrate

# Rollback
rails db:rollback
```

---

## 📊 Database Schema Details

### Social Schema

**notifications**
```ruby
user_id: integer                    # Who receives
notification_type: string           # Type of notification
title: string                      # Notification title
message: text                      # Full message
data: jsonb                        # Additional context
read: boolean                      # Read status
read_at: datetime                  # When read
```

**comments**
```ruby
user_id: integer                    # Commenter
commentable_id/type: polymorphic   # What they commented on
content: text                      # Comment text
parent_id: integer                 # For replies
likes_count: integer               # Cached count
```

**likes**
```ruby
user_id: integer                    # Who liked
likeable_id/type: polymorphic      # What they liked
```

**follows**
```ruby
user_id: integer                    # Follower
artist_id: integer                 # Who they follow
```

### Indexes

Optimized for common queries:
```ruby
# Notifications
index [:user_id, :read]
index [:user_id, :created_at]

# Comments
index [:commentable_type, :commentable_id]
index [:commentable_type, :commentable_id, :created_at]

# Likes
index [:user_id, :likeable_type, :likeable_id], unique: true

# Follows
index [:user_id, :artist_id], unique: true
```

---

## 🔐 Authorization

Using **CanCanCan** for role-based access control:

### Roles
- **Fan** (default): Can view, purchase, interact socially
- **Artist**: Can manage own content + all fan abilities
- **Admin**: Can manage everything

### Ability Rules

```ruby
if user.artist?
  can :manage, Album, artist: { user_id: user.id }
  can :manage, Event, artist: { user_id: user.id }
  can :manage, FanPass, artist: { user_id: user.id }
end

if user.fan?
  can :create, Comment
  can :create, Like
  can :create, Follow
end
```

---

## 🎵 Music Streaming

### Access Control

Every stream request checks:
1. Is user authenticated?
2. Does user own album NFT?
3. What's the track's access tier?
4. Return appropriate quality & duration

### Streaming Service

```ruby
class StreamingService
  PAYOUT_RATES = {
    free: 0.0005,           # Free tier
    preview_only: 0.0001,   # Preview tier
    nft_holder: 0.001       # Premium (NFT holders)
  }
  
  def check_access(user, track)
    owns_nft = check_nft_ownership(user, track.album)
    
    if owns_nft
      return { tier: 'premium', quality: 'lossless', duration: 'unlimited' }
    end
    
    case track.access_tier
    when 'free'
      { tier: 'free', quality: track.free_quality, duration: 'unlimited' }
    when 'preview_only'
      { tier: 'preview', quality: 'standard', duration: 30 }
    when 'nft_required'
      { allowed: false, error: 'NFT ownership required' }
    end
  end
end
```

---

## 💸 Fan Pass Dividends

### Distribution Process

1. **Artist inputs revenue** by source (streaming, sales, merch)
2. **System calculates pool** based on dividend percentage
3. **Creates dividend records** for each active holder
4. **Batch processes payments** (Solana transfers)
5. **Updates holder earnings** and sends notifications

### FanPassService

```ruby
def distribute_dividends(period_start, period_end, revenue_by_source)
  # Filter by enabled revenue sources
  relevant_revenue = revenue_by_source.select { |k, v| 
    @fan_pass.revenue_sources.include?(k.to_s) 
  }.values.sum
  
  # Calculate pool
  dividend_pool = relevant_revenue * (@fan_pass.dividend_percentage / 100.0)
  per_holder = dividend_pool / @fan_pass.active_count
  
  # Create records
  @fan_pass.fan_pass_nfts.active.each do |nft|
    nft.dividends.create!(
      amount: per_holder,
      period_start: period_start,
      period_end: period_end,
      status: :pending
    )
  end
  
  {
    total_pool: dividend_pool,
    per_holder: per_holder,
    holders: @fan_pass.active_count
  }
end
```

---

## 📹 RTMP Livestreaming

### Architecture

```
┌──────┐  RTMP   ┌──────────┐  HLS   ┌──────┐
│ OBS  │───────→ │ Node.js  │──────→ │ Fans │
└──────┘         │ +FFmpeg  │        └──────┘
                 └──────────┘
                       ↓
                 ┌──────────┐
                 │  Rails   │
                 │   API    │
                 └──────────┘
```

### Stream Lifecycle

1. **Create**: Artist creates livestream → gets RTMP credentials
2. **Configure**: Artist sets up OBS with credentials
3. **Validate**: RTMP server validates stream key with Rails API
4. **Live**: FFmpeg transcodes to HLS, Rails marks as live
5. **End**: RTMP notifies Rails, status updates to ended

### RTMP Server Webhooks

**Validate Stream** (Before accepting):
```javascript
POST /api/v1/streaming/validate
{ stream_key: "abc123..." }
```

**Stream Started**:
```javascript
POST /api/v1/streaming/stream_started  
{ stream_key: "abc123..." }
```

**Stream Ended**:
```javascript
POST /api/v1/streaming/stream_ended
{ stream_key: "abc123..." }
```

---

## 🔧 Services

### BondingCurveService

Calculates token prices using bonding curve math.

```ruby
def calculate_buy_price(amount)
  # Bonding curve: price = supply² / 1000000
  # Integral for total cost over supply change
end

def calculate_sell_price(amount)
  # Reverse bonding curve
end
```

### RevenueS plitService

Distributes revenue according to predefined splits.

```ruby
def execute_split(splittable, amount)
  split = splittable.revenue_split
  
  {
    artist: amount * (split.artist_percentage / 100.0),
    platform: amount * (split.platform_percentage / 100.0),
    dev: amount * (split.dev_percentage / 100.0)
  }
end
```

---

## 📈 Analytics & Metrics

### Platform Metrics

```ruby
class PlatformMetric < ApplicationRecord
  # Daily tracking
  - total_volume: decimal
  - total_users: integer
  - active_artists: integer
  - total_streams: integer
  - fan_pass_fees_collected: decimal
  - dividends_distributed: decimal
end
```

### Artist Analytics

Available in artist dashboard:
- Total streams
- Monthly listeners
- Revenue by source
- Follower growth
- Engagement rate

---

## 🐛 Debugging

### Logs

```bash
# Development logs
tail -f log/development.log

# Production logs (Railway)
railway logs

# Sidekiq
bundle exec sidekiq
```

### Rails Console

```bash
rails console

# Check data
User.count
Artist.count
ArtistToken.count

# Test service
service = FanPassService.new(FanPass.first)
service.distribute_dividends(...)
```

---

## 📝 TODO (Upcoming)

### Short-term
- [ ] Metaplex NFT integration
- [ ] Actual token swaps
- [ ] Fee collection implementation
- [ ] Automated dividend payments

### Long-term
- [ ] Email notifications
- [ ] Advanced analytics
- [ ] Admin dashboard
- [ ] Rate limiting
- [ ] Caching strategy

---

## 🔗 Related Documentation

- [Main README](../README.md) - Project overview
- [Frontend README](../frontend/README.md) - Frontend documentation
- [Deployment Guide](../DEPLOYMENT_GUIDE.md) - Production setup

---

**Last Updated**: November 5, 2025  
**Version**: 1.0.0  
**Status**: Active Development
