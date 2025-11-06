class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_items, dependent: :destroy
  has_many :merch_items, through: :wishlist_items
  
  validates :name, presence: true
  
  before_create :generate_share_token, if: :public?
  
  scope :public_wishlists, -> { where(public: true) }
  
  private
  
  def generate_share_token
    self.share_token = SecureRandom.urlsafe_base64(16)
  end
end

