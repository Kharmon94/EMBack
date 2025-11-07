class Genre < ApplicationRecord
  # Hierarchical structure
  belongs_to :parent_genre, class_name: 'Genre', optional: true
  has_many :subgenres, class_name: 'Genre', foreign_key: 'parent_genre_id'
  
  # Content associations
  has_many :track_genres, dependent: :destroy
  has_many :tracks, through: :track_genres
  has_many :album_genres, dependent: :destroy
  has_many :albums, through: :album_genres
  has_many :video_genres, dependent: :destroy
  has_many :videos, through: :video_genres
  has_many :event_genres, dependent: :destroy
  has_many :events, through: :event_genres
  has_many :user_genre_preferences, dependent: :destroy
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  
  scope :active, -> { where(active: true) }
  scope :root_genres, -> { where(parent_genre_id: nil).order(:position) }
  scope :popular, -> { joins(:tracks).group('genres.id').order('COUNT(tracks.id) DESC') }
  
  before_validation :generate_slug
  
  def is_root?
    parent_genre_id.nil?
  end
  
  def ancestors
    return [] if parent_genre_id.nil?
    [parent_genre] + parent_genre.ancestors
  end
  
  def descendants
    subgenres + subgenres.flat_map(&:descendants)
  end
  
  private
  
  def generate_slug
    self.slug = name.parameterize if name.present? && slug.blank?
  end
end

