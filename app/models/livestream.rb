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
