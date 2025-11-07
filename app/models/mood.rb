class Mood < ApplicationRecord
  has_many :track_moods, dependent: :destroy
  has_many :tracks, through: :track_moods
  has_many :mini_moods, dependent: :destroy
  has_many :minis, through: :mini_moods
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  
  scope :active, -> { where(active: true) }
  
  before_validation :generate_slug
  
  private
  
  def generate_slug
    self.slug = name.parameterize if name.present? && slug.blank?
  end
end

