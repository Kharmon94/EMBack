class ReviewVote < ApplicationRecord
  belongs_to :review
  belongs_to :user
  
  validates :user_id, uniqueness: { scope: :review_id }
  validates :helpful, inclusion: { in: [true, false] }
  
  after_create :update_review_counts
  after_update :update_review_counts
  after_destroy :update_review_counts
  
  private
  
  def update_review_counts
    review.update_columns(
      helpful_count: review.review_votes.where(helpful: true).count,
      not_helpful_count: review.review_votes.where(helpful: false).count
    )
  end
end

