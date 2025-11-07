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
  has_many :notifications, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :stream_messages, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :airdrop_claims, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :review_votes, dependent: :destroy
  has_many :wishlists, dependent: :destroy
  has_many :recently_viewed_items, dependent: :destroy
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants
  has_many :direct_messages, dependent: :destroy
  has_many :shares, dependent: :destroy
  has_many :user_activities, dependent: :destroy
  has_one :curator_profile, dependent: :destroy
  has_many :playlist_collaborations, class_name: 'PlaylistCollaborator', dependent: :destroy
  has_many :collaborative_playlists, through: :playlist_collaborations, source: :playlist
  has_many :playlist_follows, dependent: :destroy
  has_many :followed_playlists, through: :playlist_follows, source: :playlist
  has_many :listening_histories, dependent: :destroy
  has_many :view_histories, dependent: :destroy
  has_many :search_histories, dependent: :destroy
  has_many :recently_playeds, dependent: :destroy
  
  # Messaging preferences enum
  enum :accept_messages, { everyone: 0, following_only: 1, no_one: 2 }, default: :everyone
  
  # Validations
  validates :wallet_address, uniqueness: true, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  validates :role, presence: true
  validate :at_least_one_auth_method
  
  # Dual auth: email OR wallet required
  # Override Devise methods to allow optional email when wallet is present
  def email_required?
    # Email is required only if wallet is not present
    wallet_address.blank?
  end
  
  def email_changed?
    # Only care about email changes if using email auth
    email_changed = super
    email_changed
  end
  
  def password_required?
    # Password is required if:
    # 1. Using email auth (wallet is blank OR email is present)
    # 2. AND either creating new password or password is not set yet
    if email.present?
      encrypted_password.blank? || password.present?
    else
      false # Wallet-only users don't need password
    end
  end
  
  # Auth method helpers
  def has_email_auth?
    email.present? && encrypted_password.present?
  end
  
  def has_wallet_auth?
    wallet_address.present?
  end
  
  def can_perform_blockchain_actions?
    wallet_address.present?
  end
  
  def auth_methods
    methods = []
    methods << :email if has_email_auth?
    methods << :wallet if has_wallet_auth?
    methods
  end
  
  private
  
  def at_least_one_auth_method
    if wallet_address.blank? && (email.blank? || encrypted_password.blank?)
      errors.add(:base, 'Must have either email/password or wallet address')
    end
  end
end
