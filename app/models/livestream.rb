class Livestream < ApplicationRecord
  belongs_to :artist
  has_many :stream_messages, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  
  # Keep existing status values for backward compatibility
  enum :status, { scheduled: 0, live: 1, ended: 2, cancelled: 3 }, default: :scheduled
  
  validates :title, presence: true
  validates :token_gate_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :stream_key, uniqueness: true, allow_nil: true
  
  before_create :generate_stream_credentials
  
  scope :active, -> { where(status: :live) }
  scope :upcoming, -> { where(status: :scheduled).where("start_time > ?", Time.current) }
  
  # Full-text search with fuzzy matching
  scope :search, ->(query) {
    return all if query.blank?
    
    sanitized = query.strip.gsub(/[^a-zA-Z0-9\s]/, '')
    return none if sanitized.blank?
    
    where("title ILIKE ? OR description ILIKE ?", "%#{sanitized}%", "%#{sanitized}%")
      .order(
        Arel.sql("
          CASE 
            WHEN LOWER(title) = #{connection.quote(sanitized.downcase)} THEN 0
            WHEN title ILIKE #{connection.quote(sanitized + '%')} THEN 1
            WHEN title ILIKE #{connection.quote('%' + sanitized + '%')} THEN 2
            ELSE 3
          END,
          LENGTH(title)
        ")
      )
  }
  
  after_save :update_search_vector, if: -> { saved_change_to_title? || saved_change_to_description? }
  
  def is_token_gated?
    token_gate_amount.present? && token_gate_amount > 0
  end
  
  def is_live?
    status == 'live'
  end
  
  def start_stream!
    update!(
      status: :live,
      started_at: Time.current
    )
  end
  
  def end_stream!
    update!(
      status: :ended,
      ended_at: Time.current
    )
  end
  
  def increment_viewers!
    increment!(:viewer_count)
  end
  
  def decrement_viewers!
    decrement!(:viewer_count) if viewer_count > 0
  end
  
  def stream_duration
    return nil unless started_at
    end_time = ended_at || Time.current
    ((end_time - started_at) / 60).round # in minutes
  end
  
  private
  
  def update_search_vector
    return unless id
    artist_name = artist&.name || ''
    self.class.connection.execute(
      "UPDATE livestreams SET search_vector = " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(title || '')}, '')), 'A') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(description || '')}, '')), 'B') || " \
      "setweight(to_tsvector('english', coalesce(#{self.class.connection.quote(artist_name)}, '')), 'B') " \
      "WHERE id = #{id}"
    )
  end
  
  def generate_stream_credentials
    # Generate secure stream key
    self.stream_key = SecureRandom.hex(16)
    
    # Set RTMP URL (will be configurable via ENV)
    rtmp_host = ENV['RTMP_HOST'] || 'localhost'
    rtmp_port = ENV['RTMP_PORT'] || '1935'
    self.rtmp_url = "rtmp://#{rtmp_host}:#{rtmp_port}/live"
    
    # Set HLS URL (where fans will watch)
    hls_host = ENV['HLS_HOST'] || 'localhost'
    hls_port = ENV['HLS_PORT'] || '8000'
    self.hls_url = "http://#{hls_host}:#{hls_port}/live/#{stream_key}/index.m3u8"
  end
end
