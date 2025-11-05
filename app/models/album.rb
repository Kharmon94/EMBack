class Album < ApplicationRecord
  belongs_to :artist
  has_many :tracks, dependent: :destroy
  has_many :purchases, as: :purchasable, dependent: :destroy
  has_one :revenue_split, as: :splittable, dependent: :destroy
  
  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :released, -> { where("release_date <= ?", Date.today) }
  scope :upcoming, -> { where("release_date > ?", Date.today) }
  
  def total_duration
    tracks.sum(:duration)
  end
  
  def total_streams
    tracks.joins(:streams).count
  end
end
