class Report < ApplicationRecord
  belongs_to :user
  belongs_to :reportable, polymorphic: true
  belongs_to :reviewer, class_name: 'User', optional: true
  
  enum :status, { pending: 0, under_review: 1, resolved: 2, dismissed: 3 }, default: :pending
  
  validates :reason, presence: true
  
  scope :pending_review, -> { where(status: [:pending, :under_review]) }
  scope :recent, -> { order(created_at: :desc) }
end
