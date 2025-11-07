class CuratorProfile < ApplicationRecord
  belongs_to :user
  
  validates :display_name, presence: true
  
  scope :verified, -> { where(verified: true) }
  scope :by_specialty, ->(specialty) { where(specialty: specialty) }
  scope :popular, -> { order(followers_count: :desc) }
  
  def playlists
    user.playlists.where(public: true)
  end
end

