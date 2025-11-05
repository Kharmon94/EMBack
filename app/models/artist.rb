class Artist < ApplicationRecord
  belongs_to :user
  
  # Associations
  # NOTE: Each artist can only have ONE token (enforced via has_one relationship)
  # Combined with User.has_one(:artist), this ensures one token per wallet
  has_one :artist_token, dependent: :destroy
  has_many :albums, dependent: :destroy
  has_many :tracks, through: :albums
  has_many :videos, dependent: :destroy
  has_many :minis, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :livestreams, dependent: :destroy
  has_many :merch_items, dependent: :destroy
  has_many :fan_passes, dependent: :destroy
  has_many :airdrops, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :verified, inclusion: { in: [true, false] }
  
  # Scopes
  scope :verified, -> { where(verified: true) }
  scope :with_token, -> { joins(:artist_token) }
end
