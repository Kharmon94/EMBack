# Fan Pass Dividend NFT System

## Overview

Fan Pass NFTs are limited edition digital collectibles that grant holders exclusive perks and a share of the artist's revenue through dividend payments. This creates a sustainable fan engagement model where superfans can directly share in the artist's success.

## Core Features

### 1. **Limited Edition NFTs**
- Artists create fan pass collections with a fixed max supply (1-10,000 NFTs)
- Each NFT is a unique edition number
- Can be sold (paid), airdropped (free), or hybrid distribution
- NFTs are tradeable on secondary markets

### 2. **Revenue Sharing (Dividends)**
- Artists allocate 0-50% of selected revenue streams to dividend pool
- Dividends are distributed equally among all active holders
- Monthly distribution cycle
- Revenue sources include:
  - 🎵 Streaming royalties
  - 💿 Music sales
  - 👕 Merchandise
  - 🎟️ Ticket sales
  - 🪙 Token trading fees

### 3. **Exclusive Perks**
- **Access Perks**: Token-gated content, private communities, early releases
- **Discount Perks**: Merchandise discounts, free tickets, priority access
- **Content Perks**: Unreleased tracks, behind-the-scenes, studio access
- **Event Perks**: Meet & greets, VIP sections, after-parties
- **Governance Perks**: Vote on setlists, choose singles, influence decisions

## Database Schema

### `fan_passes` Table Extensions
```ruby
max_supply: integer              # Total NFTs in collection
minted_count: integer            # How many have been minted
collection_mint: string          # Metaplex collection address
dividend_percentage: decimal     # 0-50% of revenue to share
distribution_type: integer       # paid, airdrop, hybrid
metadata_uri: string             # NFT metadata location
revenue_sources: jsonb           # Array of revenue sources to share
image_url: string               # Collection artwork
```

### `fan_pass_nfts` Table
```ruby
fan_pass_id: integer             # Parent collection
user_id: integer                 # Current owner (nullable)
nft_mint: string                 # Unique NFT address
edition_number: integer          # Edition number in collection
status: integer                  # unclaimed, active, transferred, burned
total_dividends_earned: decimal  # Lifetime earnings
last_dividend_at: datetime       # Last payment received
claimed_at: datetime            # When NFT was claimed
```

### `dividends` Table
```ruby
fan_pass_nft_id: integer        # Which NFT received this dividend
amount: decimal                  # Amount in SOL
source: integer                  # streaming, sales, events, tokens, merch
status: integer                  # pending, processing, paid, failed
transaction_signature: string    # On-chain payment proof
period_start: date              # Revenue period start
period_end: date                # Revenue period end
calculation_details: text       # How dividend was calculated
```

## Revenue Model

### Artist Revenue Split Example
If artist earns 10 SOL/month from enabled sources with 20% dividend:

```
Total Revenue:        10.00 SOL
Dividend Pool (20%):   2.00 SOL
Artist Keeps (80%):    8.00 SOL

Per Holder (100 NFTs): 0.02 SOL/month
Per Holder (Annual):   0.24 SOL/year (~$36 @ $150/SOL)
```

### Platform Fees
- **Initial Sale**: 10% platform fee on paid NFT sales
- **Secondary Sales**: 5% royalty (enforced on-chain)
- **Dev Cut**: 20% of all platform fees collected

### Sustainability Model
- Artists earn upfront from NFT sales
- Fans earn ongoing dividends from artist success
- Platform earns fees on all transactions
- Network effects: More successful artists = more attractive fan passes

## API Endpoints

### Fan Pass Management
```
POST   /api/v1/fan_passes                    # Create fan pass
GET    /api/v1/fan_passes                    # Browse fan passes
GET    /api/v1/fan_passes/:id                # Get details
PATCH  /api/v1/fan_passes/:id                # Update settings
DELETE /api/v1/fan_passes/:id                # Deactivate
```

### NFT Purchase & Management
```
POST   /api/v1/fan_passes/:id/purchase              # Mint NFT to user
GET    /api/v1/fan_passes/:id/holders               # List all holders
GET    /api/v1/fan_passes/:id/dividends             # Dividend history
POST   /api/v1/fan_passes/:id/distribute_dividends  # Calculate & distribute
```

### Request Examples

#### Create Fan Pass
```json
POST /api/v1/fan_passes
{
  "fan_pass": {
    "name": "VIP Inner Circle",
    "description": "Exclusive access and revenue sharing",
    "max_supply": 100,
    "price": 2.0,
    "distribution_type": "paid",
    "dividend_percentage": 15,
    "revenue_sources": ["streaming", "sales", "merch"],
    "perks": {
      "access": ["Token-gated livestreams", "Private Discord"],
      "discounts": ["50% off merchandise"],
      "content": ["Unreleased tracks & demos"],
      "events": ["Meet & greet access"],
      "governance": ["Vote on setlist"]
    }
  }
}
```

#### Purchase Fan Pass NFT
```json
POST /api/v1/fan_passes/:id/purchase
{
  "transaction_signature": "5xK7mQ8..."
}

Response:
{
  "nft": {
    "id": 42,
    "nft_mint": "FANPASS_1_abc123...",
    "edition_number": 7,
    "status": "active"
  },
  "edition_number": 7,
  "platform_fee": 0.2,
  "message": "Fan pass NFT #7 minted successfully!",
  "perks": { ... },
  "dividend_info": {
    "dividend_rate": 15,
    "revenue_sources": ["streaming", "sales", "merch"],
    "estimated_monthly": "Varies based on artist revenue"
  }
}
```

#### Distribute Dividends
```json
POST /api/v1/fan_passes/:id/distribute_dividends
{
  "revenue_by_source": {
    "streaming": 5.0,
    "sales": 3.0,
    "merch": 2.0
  }
}

Response:
{
  "message": "Dividends calculated for 87 holders",
  "total_pool": 1.5,
  "per_holder": 0.01724,
  "dividends_created": 261
}
```

## Frontend Pages

### For Fans
- `/fan-passes` - Browse all fan pass collections
- `/fan-passes/:id` - View details and purchase
- `/profile/fan-passes` - View owned fan passes and earnings

### For Artists
- `/artist/fan-passes/create` - Create new fan pass collection
- `/artist/fan-passes/:id` - Manage pass and distribute dividends

## Business Logic

### FanPass Model
```ruby
# Calculate dividend distribution
def calculate_dividend(artist_revenue, period_start, period_end)
  total_pool = artist_revenue * (dividend_percentage / 100.0)
  active_holders = active_count
  per_holder = active_holders > 0 ? total_pool / active_holders : 0
  
  {
    total_pool: total_pool,
    per_holder: per_holder,
    active_holders: active_holders,
    period_start: period_start,
    period_end: period_end
  }
end
```

### FanPassService
```ruby
# Mint NFT to user
def mint_nft(user, payment_signature)
  # 1. Verify payment if required
  # 2. Calculate platform fee (10%)
  # 3. Mint NFT with next edition number
  # 4. Process fee collection
  # 5. Return NFT details
end

# Distribute dividends for period
def distribute_dividends(period_start, period_end, revenue_by_source)
  # 1. Calculate total revenue from enabled sources
  # 2. Calculate dividend pool
  # 3. Create dividend records for each holder
  # 4. Mark as pending for batch processing
end

# Process pending dividend payments
def process_pending_dividends
  # 1. Group pending dividends by holder
  # 2. Execute Solana transfers (batch)
  # 3. Mark as paid with transaction signature
  # 4. Update holder's total_dividends_earned
end
```

## Security & Validation

### Fan Pass Creation
- Max supply: 1-10,000 NFTs
- Dividend percentage: 0-50%
- Must have at least one revenue source
- Perks must be valid hash structure

### NFT Purchase
- Verify Solana transaction signature
- Check availability (not sold out)
- Verify payment amount matches price
- Ensure one purchase per transaction

### Dividend Distribution
- Only artist can distribute dividends
- Must have configured dividend percentage > 0
- Must have active holders
- Revenue amounts must be positive

## Metaplex NFT Integration (TODO)

```ruby
# Current: Placeholder mint generation
def generate_nft_mint
  "FANPASS_#{@fan_pass.id}_#{SecureRandom.hex(16)}"
end

# Future: Actual Metaplex minting
def mint_with_metaplex(edition_number)
  # 1. Create collection if first mint
  # 2. Mint NFT with metadata
  # 3. Set royalty enforcement (5%)
  # 4. Return mint address
end
```

## Analytics & Metrics

### Platform Metrics
```ruby
fan_pass_fees_collected: decimal    # Total fees from fan pass sales
dividends_distributed: decimal      # Total dividends paid out
```

### Per Fan Pass
- Total minted vs max supply
- Active holders
- Total dividends distributed
- Last distribution date
- Average holder earnings

### Per Holder
- Total dividends earned
- Last payment date
- Edition number
- Status (active, transferred, burned)

## Example Use Cases

### 1. Premium Fan Club (Paid + Dividends)
- Price: 5 SOL ($750)
- Supply: 50 NFTs
- Dividend: 25% of all revenue
- Upfront earnings: 250 SOL ($37,500)
- Ongoing: Holders share in success

### 2. Loyalty Rewards (Airdrop + No Dividends)
- Price: Free
- Supply: 1000 NFTs
- Dividend: 0%
- Airdrop to top fans/token holders
- Pure perk-based value

### 3. Hybrid Model (Low Price + High Dividends)
- Price: 0.5 SOL ($75)
- Supply: 500 NFTs
- Dividend: 30% of streaming + merch
- Lower barrier to entry
- Strong recurring value

## Future Enhancements

### Phase 1 (Current)
- ✅ NFT creation and minting
- ✅ Dividend calculation
- ✅ Manual distribution
- ✅ Perk system
- ✅ Holder tracking

### Phase 2 (Near-term)
- 🔲 Automated monthly distributions
- 🔲 Metaplex integration
- 🔲 On-chain verification
- 🔲 Secondary market tracking
- 🔲 Holder dashboard with analytics

### Phase 3 (Long-term)
- 🔲 Tiered fan passes (Bronze/Silver/Gold)
- 🔲 Staking for bonus dividends
- 🔲 Governance voting implementation
- 🔲 Cross-artist fan pass bundles
- 🔲 Dynamic perks based on holdings

## Testing

### Key Test Scenarios
1. Create fan pass with various configurations
2. Purchase NFT with Solana payment
3. Calculate and distribute dividends
4. Transfer NFT to new owner
5. Handle sold-out collections
6. Verify platform fees
7. Test dividend eligibility
8. Batch payment processing

### Test Data
```ruby
# In db/seeds.rb
artist = Artist.first
fan_pass = artist.fan_passes.create!(
  name: "VIP Club",
  max_supply: 100,
  price: 1.0,
  dividend_percentage: 20,
  revenue_sources: ["streaming", "sales"]
)

# Simulate minting
service = FanPassService.new(fan_pass)
10.times do |i|
  user = User.offset(rand(User.count)).first
  service.mint_nft(user, "TEST_SIG_#{i}")
end

# Simulate dividend distribution
service.distribute_dividends(
  1.month.ago.to_date,
  Date.today,
  { streaming: 5.0, sales: 3.0 }
)
```

## Revenue Impact

### For Artists
- **Upfront**: NFT sales (minus 10% platform fee)
- **Recurring**: Keep 50-100% of revenue (depending on dividend rate)
- **Marketing**: Superfans promote your work (they profit from your success)

### For Fans
- **Immediate**: Exclusive perks and access
- **Recurring**: Monthly dividend payments
- **Speculative**: NFT value may increase with artist success

### For Platform
- **Initial Sales**: 10% of all NFT sales
- **Secondary Sales**: 5% royalty on resales
- **Dev Fee**: 20% of all collected fees
- **Sustainable**: Revenue grows with platform activity

## Conclusion

The Fan Pass Dividend NFT system creates a win-win-win model:

1. **Artists** get upfront capital and stronger fan engagement
2. **Fans** get exclusive perks and share in artist success
3. **Platform** gets sustainable recurring revenue

This model is more sustainable than traditional fan clubs because:
- Fans are financially incentivized to promote the artist
- Artists keep majority of revenue while building loyalty
- Platform revenue grows naturally with artist success
- Network effects create virtuous cycle

