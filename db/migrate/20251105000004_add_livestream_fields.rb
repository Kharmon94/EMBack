class AddLivestreamFields < ActiveRecord::Migration[8.0]
  def change
    # Add new RTMP/HLS streaming fields
    add_column :livestreams, :stream_key, :string
    add_column :livestreams, :rtmp_url, :string
    add_column :livestreams, :hls_url, :string
    add_column :livestreams, :started_at, :datetime
    add_column :livestreams, :ended_at, :datetime
    
    # Note: status and viewer_count already exist from previous migrations
    
    add_index :livestreams, :stream_key, unique: true
  end
end

