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
  
  # Validations
  validates :wallet_address, uniqueness: true, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  validates :role, presence: true
  validate :at_least_one_auth_method
  
  # Dual auth: email OR wallet required (not both)
  def email_required?
    wallet_address.blank?
  end
  
  def email_changed?
    super && wallet_address.blank?
  end
  
  def password_required?
    wallet_address.blank? && (encrypted_password.blank? || password.present?)
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
