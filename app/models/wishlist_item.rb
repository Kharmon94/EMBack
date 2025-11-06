class WishlistItem < ApplicationRecord
  belongs_to :wishlist
  belongs_to :merch_item
  belongs_to :product_variant, optional: true
  
  validates :merch_item_id, uniqueness: { scope: :wishlist_id }
end

