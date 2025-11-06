class ProductTag < ApplicationRecord
  has_many :merch_item_tags, dependent: :destroy
  has_many :merch_items, through: :merch_item_tags
  
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end

