class SearchHistory < ApplicationRecord
  belongs_to :user, optional: true # Can track guest searches too
  
  validates :query, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :popular_searches, -> {
    where('created_at > ?', 7.days.ago)
      .group(:query)
      .order('COUNT(*) DESC')
      .limit(10)
      .pluck(:query, 'COUNT(*) as count')
  }
  
  # Track a search
  def self.track_search(user:, query:, search_type: 'all', results_count: 0)
    create(
      user: user,
      query: query,
      search_type: search_type,
      results_count: results_count
    )
  end
  
  # Track when user clicks a result
  def track_click(result)
    update(
      clicked_result: true,
      clicked_result_type: result.class.name,
      clicked_result_id: result.id
    )
  end
end

