class User < ApplicationRecord
  # Include default devise modules with JWT support
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
  
  # Enums
  enum :role, { fan: 0, artist: 1, admin: 2 }, default: :fan
  
  # Associations
  # NOTE: One wallet → One user → One artist → One token
  # This enforces the "one token per wallet" policy at the database level
  has_one :artist, dependent: :destroy
  has_many :trades, dependent: :destroy
  has_many :streams, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :stream_messages, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :airdrop_claims, dependent: :destroy
  
  # Validations
  validates :wallet_address, presence: true, uniqueness: true
  validates :role, presence: true
  
  # Allow wallet-based auth (email can be optional)
  def email_required?
    false
  end
  
  def email_changed?
    false
  end
end
