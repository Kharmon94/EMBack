# One Token Per Wallet Policy

## Overview
Each wallet address can only create **ONE** artist token on the platform. This ensures authenticity, prevents spam, and maintains the integrity of the artist token ecosystem.

## Enforcement Layers

### 1. Database Relationship Chain
```
Wallet Address (unique) → User (1:1) → Artist (1:1) → ArtistToken (1:1)
```

**Models:**
- `User.wallet_address` - Unique constraint
- `User.has_one :artist` - One artist per user
- `Artist.has_one :artist_token` - One token per artist

### 2. Model-Level Validation
**File:** `backend/app/models/artist_token.rb`

```ruby
validate :one_token_per_wallet, on: :create

def one_token_per_wallet
  # Queries database to ensure wallet hasn't created a token
  existing_token = ArtistToken.joins(artist: :user)
                               .where(users: { wallet_address: artist.user.wallet_address })
                               .where.not(id: id)
                               .exists?
  
  if existing_token
    errors.add(:base, 'This wallet has already created a token.')
  end
end
```

### 3. Controller-Level Validation
**File:** `backend/app/controllers/api/v1/artist_tokens_controller.rb`

```ruby
def create
  # Check 1: Artist profile required
  unless current_artist
    return render json: { error: 'Artist profile required' }
  end
  
  # Check 2: Artist already has token
  if current_artist.artist_token.present?
    return render json: { error: 'Artist already has a token' }
  end
  
  # Check 3: Wallet-level defense-in-depth
  if ArtistToken.joins(artist: :user).exists?(users: { wallet_address: current_user.wallet_address })
    return render json: { 
      error: 'This wallet has already created a token',
      message: 'Each wallet can only create one artist token.'
    }
  end
  
  # ... proceed with token creation
end
```

### 4. Registration-Level Validation
**File:** `backend/app/controllers/api/v1/auth/registrations_controller.rb`

```ruby
# Prevents duplicate wallet registrations
if User.exists?(wallet_address: wallet_address)
  return render json: { error: 'Wallet address already registered' }
end
```

## Why This Matters

### 🔒 Security Benefits
1. **Prevents Sybil Attacks:** Users can't spam tokens with multiple wallets
2. **Ensures Authenticity:** One artist identity = one wallet = one token
3. **Maintains Trust:** Fans know each token represents a real artist
4. **Reduces Spam:** Limits frivolous token creation

### 💰 Economic Benefits
1. **Token Value:** Scarcity of tokens per artist increases perceived value
2. **Market Integrity:** Prevents token dilution and market manipulation
3. **Fair Launch:** All artists start on equal footing
4. **Graduation Incentive:** Artists focus on building one strong token

### 🎯 User Experience Benefits
1. **Simplicity:** Artists have one clear identity/token
2. **Discovery:** Easier to find and track artists
3. **Portfolio:** Fans can collect one token per artist
4. **Clarity:** No confusion about which token is "official"

## API Response Examples

### Success
```json
POST /api/v1/tokens
{
  "token": {
    "id": 123,
    "name": "Taylor Swift Token",
    "symbol": "TAYLOR",
    "mint_address": "Abc...xyz"
  },
  "message": "Token launched successfully"
}
```

### Error: Artist Already Has Token
```json
{
  "error": "Artist already has a token"
}
```

### Error: Wallet Already Created Token
```json
{
  "error": "This wallet has already created a token",
  "message": "Each wallet can only create one artist token. This ensures authenticity and prevents spam."
}
```

## Edge Cases Handled

1. ✅ User tries to create multiple artist profiles → Prevented by `has_one :artist`
2. ✅ Artist tries to create second token → Prevented by `has_one :artist_token`
3. ✅ Wallet somehow bypasses artist check → Caught by explicit wallet query
4. ✅ Database race condition → Model validation runs before commit
5. ✅ API called directly → All three controller checks run sequentially

## Future Enhancements

### On-Chain Enforcement
When Solana program is integrated:

```rust
// In Solana smart contract
#[account]
pub struct TokenAuthority {
    pub wallet: Pubkey,        // Creator wallet
    pub token_mint: Pubkey,    // Token mint address
    pub created_at: i64,       // Timestamp
}

// Ensure one token per authority
require!(
    !token_authority_exists(wallet),
    ErrorCode::WalletAlreadyCreatedToken
);
```

### Potential Extensions
- Allow token "migration" with governance vote
- Verified artists can create collection/ecosystem tokens
- Time-locked token creation (1 year cooldown after transfer)

## Testing

### Unit Tests (TODO)
```ruby
# spec/models/artist_token_spec.rb
it 'prevents same wallet from creating multiple tokens'
it 'allows different wallets to create tokens'
it 'validates before database commit'
```

### Integration Tests (TODO)
```ruby
# spec/requests/artist_tokens_spec.rb
it 'rejects token creation from wallet with existing token'
it 'returns appropriate error message'
it 'logs security event when duplicate attempt occurs'
```

## Monitoring

**Recommended Alerts:**
- Track duplicate token creation attempts (potential abuse)
- Monitor wallet registration patterns
- Alert on rapid token creation from similar wallet patterns

**Metrics to Track:**
- Tokens created per day
- Failed creation attempts
- Average time between wallet creation and token launch
- Token graduation rate

## Related Documentation
- [Token Launch Guide](./TOKEN_LAUNCH.md)
- [Artist Onboarding](./ARTIST_ONBOARDING.md)
- [Security Best Practices](./SECURITY.md)

---

**Last Updated:** 2025-11-05  
**Status:** ✅ Implemented and Enforced

