# frozen_string_literal: true

# Clear existing data (be careful in production!)
puts "🗑️  Cleaning database..."
[
  AirdropClaim, Airdrop, OrderItem, Order, Purchase, FanPass, MerchItem,
  StreamMessage, Livestream, Ticket, TicketTier, Event, RevenueSplit,
  PlaylistTrack, Playlist, Stream, Track, Album, Follow, Trade,
  LiquidityPool, ArtistToken, Artist, Report, User, PlatformMetric, PlatformToken
].each do |model|
  model.destroy_all
end

puts "✅ Database cleaned!"
puts "\n🌱 Seeding database...\n\n"

# ============================================================
# USERS
# ============================================================
puts "👥 Creating users..."

# Admin
admin = User.create!(
  wallet_address: "AdminWallet1234567890abcdefghijk",
  email: "admin@musicplatform.com",
  password: "password123",
  role: :admin
)

# Artists
artist_wallets = [
  "ArtistWallet111aaaaaaaaaaaaaaaaaaa",
  "ArtistWallet222bbbbbbbbbbbbbbbbbb",
  "ArtistWallet333cccccccccccccccccc",
  "ArtistWallet444dddddddddddddddddd",
  "ArtistWallet555eeeeeeeeeeeeeeeeee"
]

artist_users = artist_wallets.map do |wallet|
  User.create!(
    wallet_address: wallet,
    email: "artist.#{wallet[13..16]}@example.com",
    password: "password123",
    role: :artist
  )
end

# Fans
fan_wallets = (1..20).map { |i| "FanWallet#{i.to_s.rjust(3, '0')}#{'a' * 20}" }
fan_users = fan_wallets.map do |wallet|
  User.create!(
    wallet_address: wallet,
    email: "fan.#{wallet[10..13]}@example.com",
    password: "password123",
    role: :fan
  )
end

puts "✅ Created #{User.count} users (1 admin, #{artist_users.count} artists, #{fan_users.count} fans)"

# ============================================================
# ARTISTS
# ============================================================
puts "\n🎤 Creating artists..."

artist_names = [
  { name: "Luna Eclipse", bio: "Electronic dream pop from the future", verified: true },
  { name: "The Crypto Collective", bio: "Decentralized music collective", verified: true },
  { name: "Solana Sunset", bio: "Chill beats for blockchain vibes", verified: false },
  { name: "DJ Diamond Hands", bio: "EDM producer and DeFi enthusiast", verified: true },
  { name: "Blockchain Bandits", bio: "Rock meets Web3", verified: false }
]

artists = artist_users.each_with_index.map do |user, index|
  Artist.create!(
    user: user,
    name: artist_names[index][:name],
    bio: artist_names[index][:bio],
    verified: artist_names[index][:verified],
    avatar_url: "https://picsum.photos/seed/artist#{index}/400/400"
  )
end

puts "✅ Created #{artists.count} artists"

# ============================================================
# ARTIST TOKENS
# ============================================================
puts "\n🪙 Creating artist tokens..."

artists.each_with_index do |artist, index|
  base_price = [0.001, 0.005, 0.01, 0.015, 0.002][index]
  graduated = [true, false, false, true, false][index]
  
  ArtistToken.create!(
    artist: artist,
    name: "#{artist.name} Token",
    symbol: artist.name.split.map(&:first).join.upcase,
    mint_address: "Token#{index}Mint#{'1' * 32}",
    supply: 1_000_000,
    price_usd: base_price,
    graduated: graduated
  )
end

puts "✅ Created #{ArtistToken.count} artist tokens"

# ============================================================
# LIQUIDITY POOLS
# ============================================================
puts "\n💧 Creating liquidity pools..."

ArtistToken.where(graduated: true).each_with_index do |token, index|
  platforms = [:raydium_cpmm, :raydium_clmm]
  
  LiquidityPool.create!(
    artist_token: token,
    pool_address: "Pool#{index}Address#{'2' * 32}",
    platform: platforms[index % 2],
    reserve_token: 500_000,
    reserve_sol: 500_000 * token.price_usd,
    tvl: 500_000 * token.price_usd * 2
  )
end

puts "✅ Created #{LiquidityPool.count} liquidity pools"

# ============================================================
# ALBUMS & TRACKS
# ============================================================
puts "\n💿 Creating albums and tracks..."

album_count = 0
track_count = 0

artists.each_with_index do |artist, artist_index|
  # 2-3 albums per artist
  (2..3).to_a.sample.times do |album_index|
    album = Album.create!(
      artist: artist,
      title: ["Debut", "Sophomore", "Greatest Hits", "Live Sessions", "Remixed"][album_index] + " #{rand(2020..2024)}",
      description: "An amazing collection of tracks from #{artist.name}",
      release_date: rand(1..365).days.ago,
      price: [9.99, 12.99, 14.99, 0].sample, # Some free albums
      cover_url: "https://picsum.photos/seed/album#{artist_index}#{album_index}/600/600"
    )
    
    album_count += 1
    
    # 8-12 tracks per album
    num_tracks = rand(8..12)
    num_tracks.times do |track_index|
      # Artist-controlled access tiers
      # First 2-3 tracks usually free for promotion
      # Some previews to create interest
      # Rest gated for NFT holders
      access_tier = if track_index < 2
                      0 # free
                    elsif track_index < 4
                      1 # preview_only
                    else
                      [0, 1, 2].sample # mix of all tiers
                    end
      
      Track.create!(
        album: album,
        title: "Track #{track_index + 1} - #{['Sunrise', 'Moonlight', 'Dreams', 'Journey', 'Echoes', 'Wavelength'].sample}",
        duration: rand(120..300), # 2-5 minutes
        track_number: track_index + 1,
        audio_cid: "Qm#{SecureRandom.hex(20)}",
        price: [0.99, 1.99, 0].sample,
        isrc: "US#{rand(10..99)}#{rand(1000000..9999999)}",
        explicit: [true, false].sample,
        access_tier: access_tier,
        free_quality: [0, 1].sample # standard or high
      )
      
      track_count += 1
    end
  end
end

puts "✅ Created #{album_count} albums and #{track_count} tracks"

# ============================================================
# STREAMS
# ============================================================
puts "\n🎵 Creating streams..."

tracks = Track.all
stream_count = 0

fan_users.each do |fan|
  # Each fan streams 5-20 random tracks
  tracks.sample(rand(5..20)).each do |track|
    # Random listen duration (30-300 seconds)
    duration = rand(30..300)
    
    Stream.create!(
      user: fan,
      track: track,
      duration: duration,
      listened_at: rand(1..30).days.ago
    )
    
    stream_count += 1
  end
end

puts "✅ Created #{stream_count} streams"

# ============================================================
# TRADES
# ============================================================
puts "\n💹 Creating trades..."

tokens = ArtistToken.all
trade_count = 0

fan_users.each do |fan|
  # Each fan makes 3-10 trades
  rand(3..10).times do
    token = tokens.sample
    trade_type = [:buy, :sell].sample
    amount = rand(10..1000)
    
    # Price with some variance
    price = token.price_usd * (0.9 + rand * 0.2)
    
    Trade.create!(
      user: fan,
      artist_token: token,
      trade_type: trade_type,
      amount: amount,
      price: price,
      created_at: rand(1..30).days.ago
    )
    
    trade_count += 1
  end
end

puts "✅ Created #{trade_count} trades"

# ============================================================
# EVENTS & TICKETS
# ============================================================
puts "\n🎟️ Creating events and tickets..."

event_count = 0
ticket_count = 0

artists.each_with_index do |artist, index|
  # 1-2 events per artist
  rand(1..2).times do |event_index|
    event = Event.create!(
      artist: artist,
      title: ["Live Concert", "Album Release Party", "Exclusive Showcase", "Virtual Performance"][event_index],
      description: "Don't miss this amazing event with #{artist.name}!",
      venue: ["The Blockchain Arena", "Crypto Convention Center", "NFT Gallery", "Metaverse Stage"].sample,
      start_time: rand(1..60).days.from_now,
      end_time: rand(61..90).days.from_now,
      capacity: rand(100..1000),
      status: [:published, :ongoing].sample
    )
    
    event_count += 1
    
    # 2-4 ticket tiers
    rand(2..4).times do |tier_index|
      tier_names = ["General Admission", "VIP", "Early Bird", "Backstage Pass"]
      tier_prices = [50, 150, 75, 300]
      
      tier = TicketTier.create!(
        event: event,
        name: tier_names[tier_index],
        price: tier_prices[tier_index],
        quantity: rand(20..100),
        sold: rand(0..50),
        description: "#{tier_names[tier_index]} access to the event"
      )
      
      # Create some tickets for fans
      rand(3..10).times do
        Ticket.create!(
          ticket_tier: tier,
          user: fan_users.sample,
          nft_mint: "NFT#{SecureRandom.hex(16)}",
          qr_code: SecureRandom.urlsafe_base64(32),
          status: [:active, :used].sample
        )
        
        ticket_count += 1
      end
    end
  end
end

puts "✅ Created #{event_count} events and #{ticket_count} tickets"

# ============================================================
# LIVESTREAMS
# ============================================================
puts "\n📺 Creating livestreams..."

artists.each_with_index do |artist, index|
  # 1-2 livestreams per artist
  rand(1..2).times do |stream_index|
    status = [:scheduled, :live, :ended].sample
    
    Livestream.create!(
      artist: artist,
      title: ["Live Q&A", "Studio Session", "Exclusive Performance", "Behind the Scenes"][stream_index % 4],
      description: "Join #{artist.name} for an exclusive livestream!",
      stream_url: "https://stream.example.com/#{artist.id}/#{stream_index}",
      status: status,
      start_time: status == :scheduled ? rand(1..7).days.from_now : rand(1..7).days.ago,
      viewer_count: status == :live ? rand(50..500) : rand(100..1000),
      token_gate_amount: [0, 100, 500, 1000].sample
    )
  end
end

puts "✅ Created #{Livestream.count} livestreams"

# ============================================================
# LIVESTREAM MESSAGES
# ============================================================
puts "\n💬 Creating livestream messages..."

Livestream.where(status: [:live, :ended]).each do |livestream|
  # 10-30 messages per livestream
  rand(10..30).times do
    user = [livestream.artist.user, *fan_users.sample(5)].sample
    
    StreamMessage.create!(
      livestream: livestream,
      user: user,
      content: [
        "Amazing performance! 🎵",
        "Love this track!",
        "When's the next show?",
        "Just bought your token!",
        "This is 🔥🔥🔥",
        "Sending love from the community!"
      ].sample,
      tip_amount: [0, 0, 0, 0.1, 0.5, 1.0].sample,
      tip_mint: "SOL",
      sent_at: rand(1..60).minutes.ago
    )
  end
end

puts "✅ Created #{StreamMessage.count} livestream messages"

# ============================================================
# MERCH ITEMS
# ============================================================
puts "\n👕 Creating merch items..."

artists.each_with_index do |artist, index|
  # 3-5 merch items per artist
  rand(3..5).times do |item_index|
    items = [
      { title: "Official T-Shirt", price: 29.99, inventory: 100 },
      { title: "Limited Edition Vinyl", price: 49.99, inventory: 50 },
      { title: "Tour Poster", price: 19.99, inventory: 200 },
      { title: "Signed Album", price: 99.99, inventory: 25 },
      { title: "Hoodie", price: 59.99, inventory: 75 }
    ]
    
    item = items[item_index % items.length]
    
    MerchItem.create!(
      artist: artist,
      title: "#{artist.name} - #{item[:title]}",
      description: "Official merchandise from #{artist.name}",
      price: item[:price],
      inventory_count: item[:inventory],
      variants: { sizes: ["S", "M", "L", "XL"], colors: ["Black", "White"] },
      images: [
        "https://picsum.photos/seed/merch#{index}#{item_index}/600/600",
        "https://picsum.photos/seed/merch#{index}#{item_index}b/600/600"
      ]
    )
  end
end

puts "✅ Created #{MerchItem.count} merch items"

# ============================================================
# FAN PASSES
# ============================================================
puts "\n⭐ Creating fan passes..."

artists.each_with_index do |artist, index|
  # 1-2 fan passes per artist
  rand(1..2).times do |pass_index|
    pass_types = [
      { name: "Basic Fan Pass", price: 9.99, perks: ["Early access to releases", "Exclusive chat access"] },
      { name: "VIP Fan Pass", price: 49.99, perks: ["All Basic perks", "Monthly Q&A", "Exclusive merchandise", "Backstage access to events"] }
    ]
    
    pass = pass_types[pass_index % 2]
    
    FanPass.create!(
      artist: artist,
      name: "#{artist.name} #{pass[:name]}",
      description: "Get exclusive perks from #{artist.name}!",
      price: pass[:price],
      token_gate_amount: pass_index == 1 ? 1000 : 0,
      perks: pass[:perks],
      active: true
    )
  end
end

puts "✅ Created #{FanPass.count} fan passes"

# ============================================================
# ORDERS
# ============================================================
puts "\n📦 Creating orders..."

order_count = 0

fan_users.sample(10).each do |fan|
  # 1-3 orders per fan
  rand(1..3).times do
    merch_items = MerchItem.all.sample(rand(1..3))
    total = merch_items.sum(&:price)
    
    order = Order.create!(
      user: fan,
      status: [:paid, :processing, :shipped, :delivered].sample,
      total_amount: total,
      shipping_address: {
        street: "#{rand(100..999)} Blockchain Blvd",
        city: "Crypto City",
        state: "CA",
        zip: "#{rand(10000..99999)}",
        country: "USA"
      },
      tracking_number: rand(1..2) == 1 ? "TRACK#{rand(100000..999999)}" : nil
    )
    
    merch_items.each do |item|
      OrderItem.create!(
        order: order,
        orderable: item,
        quantity: rand(1..3),
        price: item.price
      )
    end
    
    order_count += 1
  end
end

puts "✅ Created #{order_count} orders with #{OrderItem.count} items"

# ============================================================
# PURCHASES
# ============================================================
puts "\n💳 Creating purchases..."

purchase_count = 0

fan_users.each do |fan|
  # Random purchases of tracks, albums, fan passes
  rand(2..5).times do
    purchasable = [Track.all.sample, Album.all.sample, FanPass.all.sample].sample
    price = purchasable.respond_to?(:price) ? purchasable.price : 0
    
    if price && price > 0
      Purchase.create!(
        user: fan,
        purchasable: purchasable,
        price_paid: price,
        transaction_signature: "TXN#{SecureRandom.hex(32)}"
      )
      
      purchase_count += 1
    end
  end
end

puts "✅ Created #{purchase_count} purchases"

# ============================================================
# PLAYLISTS
# ============================================================
puts "\n📝 Creating playlists..."

fan_users.sample(15).each_with_index do |fan, index|
  # 1-3 playlists per fan
  rand(1..3).times do |playlist_index|
    playlist = Playlist.create!(
      user: fan,
      title: ["Favorites", "Workout", "Chill Vibes", "Party Mix", "Study Music"][playlist_index % 5],
      description: "My #{['favorite', 'workout', 'chill', 'party', 'study'][playlist_index % 5]} tracks",
      is_public: [true, false].sample
    )
    
    # Add 5-15 tracks
    Track.all.sample(rand(5..15)).each_with_index do |track, position|
      PlaylistTrack.create!(
        playlist: playlist,
        track: track,
        position: position
      )
    end
  end
end

puts "✅ Created #{Playlist.count} playlists with #{PlaylistTrack.count} tracks"

# ============================================================
# FOLLOWS
# ============================================================
puts "\n👥 Creating follows..."

fan_users.each do |fan|
  # Each fan follows 2-5 artists
  artists.sample(rand(2..5)).each do |artist|
    Follow.create!(
      user: fan,
      followable: artist
    )
  end
end

puts "✅ Created #{Follow.count} follows"

# ============================================================
# AIRDROPS
# ============================================================
puts "\n🎁 Creating airdrops..."

artists.sample(3).each_with_index do |artist, index|
  Airdrop.create!(
    artist: artist,
    artist_token: artist.artist_token,
    merkle_root: "Root#{SecureRandom.hex(32)}",
    program_address: "Program#{SecureRandom.hex(16)}",
    total_amount: 10000,
    claimed_amount: rand(1000..5000),
    start_date: 7.days.ago,
    end_date: 30.days.from_now
  )
end

puts "✅ Created #{Airdrop.count} airdrops"

# ============================================================
# AIRDROP CLAIMS
# ============================================================
puts "\n🎟️ Creating airdrop claims..."

Airdrop.all.each do |airdrop|
  fan_users.sample(rand(5..15)).each do |fan|
    is_claimed = [true, false].sample
    
    AirdropClaim.create!(
      airdrop: airdrop,
      user: fan,
      amount: rand(100..1000),
      claimed_at: is_claimed ? rand(1..30).days.ago : nil,
      transaction_signature: is_claimed ? "TXN#{SecureRandom.hex(32)}" : nil
    )
  end
end

puts "✅ Created #{AirdropClaim.count} airdrop claims"

# ============================================================
# REVENUE SPLITS
# ============================================================
puts "\n💰 Creating revenue splits..."

# For albums
Album.all.sample(5).each do |album|
  RevenueSplit.create!(
    splittable: album,
    recipients: {
      artist: 70,
      producer: 20,
      platform: 10
    }
  )
end

# For events
Event.all.sample(3).each do |event|
  RevenueSplit.create!(
    splittable: event,
    recipients: {
      artist: 80,
      venue: 15,
      platform: 5
    }
  )
end

puts "✅ Created #{RevenueSplit.count} revenue splits"

# ============================================================
# REPORTS
# ============================================================
puts "\n🚩 Creating reports..."

fan_users.sample(5).each do |fan|
  reportables = [Track.all.sample, Album.all.sample, Artist.all.sample, User.where(role: :fan).sample].sample
  
  Report.create!(
    user: fan,
    reportable: reportables,
    reason: [
      "Inappropriate content",
      "Copyright violation",
      "Spam or misleading",
      "Offensive behavior",
      "Other"
    ].sample,
    status: [:pending, :under_review, :resolved].sample
  )
end

puts "✅ Created #{Report.count} reports"

# ============================================================
# PLATFORM TOKEN & METRICS
# ============================================================
puts "\n📊 Creating platform token and metrics..."

platform_token = PlatformToken.create!(
  name: "Music Platform Token",
  symbol: "MUSIC",
  mint_address: "PlatformToken#{SecureRandom.hex(16)}",
  total_supply: 1_000_000_000,
  circulating_supply: 100_000_000,
  price_usd: 0.01,
  market_cap: 1_000_000
)

# Create 30 days of metrics
30.times do |i|
  date = i.days.ago.to_date
  
  PlatformMetric.create!(
    date: date,
    daily_volume: rand(10000..100000),
    fees_collected: rand(100..1000),
    tokens_burned: rand(1000..10000),
    active_users: rand(50..500),
    new_tokens: rand(1..10),
    total_streams: rand(1000..10000)
  )
end

puts "✅ Created platform token and #{PlatformMetric.count} days of metrics"

# ============================================================
# SUMMARY
# ============================================================
puts "\n" + "="*60
puts "🎉 SEEDING COMPLETE!"
puts "="*60
puts "\n📊 Database Summary:\n\n"

summary = {
  "Users" => User.count,
  "Artists" => Artist.count,
  "Artist Tokens" => ArtistToken.count,
  "Albums" => Album.count,
  "Tracks" => Track.count,
  "Streams" => Stream.count,
  "Trades" => Trade.count,
  "Events" => Event.count,
  "Tickets" => Ticket.count,
  "Livestreams" => Livestream.count,
  "Messages" => StreamMessage.count,
  "Merch Items" => MerchItem.count,
  "Fan Passes" => FanPass.count,
  "Orders" => Order.count,
  "Purchases" => Purchase.count,
  "Playlists" => Playlist.count,
  "Follows" => Follow.count,
  "Airdrops" => Airdrop.count,
  "Reports" => Report.count,
  "Platform Metrics" => PlatformMetric.count
}

summary.each do |model, count|
  puts "  #{model.ljust(20)} : #{count.to_s.rjust(5)}"
end

puts "\n" + "="*60
puts "\n🔑 Test Credentials:\n\n"
puts "  Admin:"
puts "    Email: admin@musicplatform.com"
puts "    Password: password123"
puts "\n  Artist:"
puts "    Email: artist.Wal1@example.com"
puts "    Password: password123"
puts "\n  Fan:"
puts "    Email: fan.Wal1@example.com"
puts "    Password: password123"
puts "\n" + "="*60
puts "\n✅ You can now start the server and test the platform!"
puts "🚀 Run: rails server\n\n"
