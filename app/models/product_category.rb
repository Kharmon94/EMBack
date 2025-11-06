class ProductCategory < ApplicationRecord
  has_many :merch_items
  belongs_to :parent, class_name: 'ProductCategory', optional: true
  has_many :subcategories, class_name: 'ProductCategory', foreign_key: 'parent_id'
  
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  
  scope :active, -> { where(active: true) }
  scope :root_categories, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :name) }
  
  def full_path
    parent ? "#{parent.full_path} > #{name}" : name
  end
end

