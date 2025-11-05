class Event < ApplicationRecord
  belongs_to :artist
  has_many :ticket_tiers, dependent: :destroy
  has_many :tickets, through: :ticket_tiers
  has_one :revenue_split, as: :splittable, dependent: :destroy
  
  enum :status, { draft: 0, published: 1, ongoing: 2, completed: 3, cancelled: 4 }, default: :draft
  
  validates :title, :venue, :start_time, :capacity, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  
  scope :upcoming, -> { where("start_time > ?", Time.current).where(status: [:published, :ongoing]) }
  scope :past, -> { where("end_time < ?", Time.current) }
  scope :active, -> { where(status: [:published, :ongoing]) }
  
  def sold_tickets_count
    ticket_tiers.sum(:sold)
  end
  
  def available_capacity
    capacity - sold_tickets_count
  end
  
  def is_sold_out?
    available_capacity <= 0
  end
end
