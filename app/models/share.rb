class Share < ApplicationRecord
  belongs_to :user
  belongs_to :shareable, polymorphic: true
  
  validates :share_type, presence: true, inclusion: { in: %w[social_media copy_link dm email] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(share_type: type) }
end

