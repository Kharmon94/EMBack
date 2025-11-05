class AddAccessControlToTracks < ActiveRecord::Migration[8.0]
  def change
    # Per-track access control
    add_column :tracks, :access_tier, :integer, default: 0, null: false
    add_column :tracks, :free_quality, :integer, default: 0, null: false
    
    # Add indexes for performance
    add_index :tracks, :access_tier
    add_index :tracks, [:album_id, :access_tier]
  end
end

