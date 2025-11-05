class StreamingRtmpService
  def initialize(livestream)
    @livestream = livestream
  end
  
  # Validate stream key for RTMP authentication
  def self.validate_stream_key(stream_key)
    livestream = Livestream.find_by(stream_key: stream_key)
    
    if livestream.nil?
      return { valid: false, error: 'Invalid stream key' }
    end
    
    unless livestream.artist
      return { valid: false, error: 'No artist associated with stream' }
    end
    
    # Check if stream is scheduled or live (can continue streaming)
    unless livestream.scheduled? || livestream.live?
      return { valid: false, error: 'Stream is not active' }
    end
    
    {
      valid: true,
      livestream_id: livestream.id,
      artist_id: livestream.artist_id,
      title: livestream.title
    }
  end
  
  # Called when stream goes live
  def self.on_stream_start(stream_key)
    livestream = Livestream.find_by(stream_key: stream_key)
    return false unless livestream
    
    livestream.start_stream!
    
    # Broadcast to ActionCable that stream started
    ActionCable.server.broadcast(
      "livestream_#{livestream.id}",
      {
        type: 'stream_started',
        livestream_id: livestream.id,
        started_at: livestream.started_at
      }
    )
    
    Rails.logger.info("Stream started: #{livestream.title} (#{livestream.id})")
    true
  end
  
  # Called when stream ends
  def self.on_stream_end(stream_key)
    livestream = Livestream.find_by(stream_key: stream_key)
    return false unless livestream
    
    livestream.end_stream!
    
    # Broadcast to ActionCable that stream ended
    ActionCable.server.broadcast(
      "livestream_#{livestream.id}",
      {
        type: 'stream_ended',
        livestream_id: livestream.id,
        ended_at: livestream.ended_at,
        duration: livestream.stream_duration
      }
    )
    
    Rails.logger.info("Stream ended: #{livestream.title} (#{livestream.id})")
    true
  end
  
  # Get stream status
  def status
    {
      id: @livestream.id,
      status: @livestream.status,
      is_live: @livestream.is_live?,
      viewer_count: @livestream.viewer_count,
      started_at: @livestream.started_at,
      duration: @livestream.stream_duration
    }
  end
  
  # Get RTMP credentials for artist
  def credentials
    {
      rtmp_url: @livestream.rtmp_url,
      stream_key: @livestream.stream_key,
      full_url: "#{@livestream.rtmp_url}/#{@livestream.stream_key}",
      hls_url: @livestream.hls_url
    }
  end
  
  # Track viewer joining
  def viewer_joined
    @livestream.increment_viewers!
    broadcast_viewer_update
  end
  
  # Track viewer leaving
  def viewer_left
    @livestream.decrement_viewers!
    broadcast_viewer_update
  end
  
  private
  
  def broadcast_viewer_update
    ActionCable.server.broadcast(
      "livestream_#{@livestream.id}",
      {
        type: 'viewer_count_update',
        viewer_count: @livestream.viewer_count
      }
    )
  end
end

