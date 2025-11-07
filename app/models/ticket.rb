class Ticket < ApplicationRecord
  belongs_to :ticket_tier
  belongs_to :user
  has_one :event, through: :ticket_tier
  
  enum :status, { active: 0, used: 1, refunded: 2, transferred: 3 }, default: :active, prefix: :ticket
  
  validates :nft_mint, uniqueness: true, allow_nil: true
  validates :qr_code, presence: true
  validates :purchased_at, presence: true
  
  before_create :generate_qr_code
  
  scope :valid_tickets, -> { where(status: :active) }
  scope :for_event, ->(event_id) { joins(:ticket_tier).where(ticket_tiers: { event_id: event_id }) }
  
  def mark_as_used!
    update!(status: :used, used_at: Time.current)
  end
  
  def can_be_used?
    ticket_active? && !used_at
  end
  
  private
  
  def generate_qr_code
    require 'securerandom'
    self.qr_code ||= SecureRandom.urlsafe_base64(32)
  end
end
