class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_id', dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  
  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }
  
  scope :root_comments, -> { where(parent_id: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { order(likes_count: :desc) }
  
  # Check if comment is a reply
  def reply?
    parent_id.present?
  end
  
  # Get all nested replies
  def all_replies
    replies.includes(:user, :replies)
  end
  
  # Increment likes count (will be used by likes system)
  def increment_likes!
    increment!(:likes_count)
  end
  
  def decrement_likes!
    decrement!(:likes_count) if likes_count > 0
  end
end

