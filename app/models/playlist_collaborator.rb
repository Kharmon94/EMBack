class PlaylistCollaborator < ApplicationRecord
  belongs_to :playlist
  belongs_to :user
  
  validates :role, presence: true, inclusion: { in: %w[owner editor viewer] }
  validates :user_id, uniqueness: { scope: :playlist_id }
  
  scope :owners, -> { where(role: 'owner') }
  scope :editors, -> { where(role: 'editor') }
  scope :viewers, -> { where(role: 'viewer') }
end

