class RecentlyViewedItem < ApplicationRecord
  belongs_to :user
  belongs_to :merch_item
  
  validates :user_id, uniqueness: { scope: :merch_item_id }
  
  scope :recent, -> { order(viewed_at: :desc) }
  
  def self.track_view(user, merch_item)
    item = find_or_initialize_by(user: user, merch_item: merch_item)
    item.viewed_at = Time.current
    item.save
  end
end

