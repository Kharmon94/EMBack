class AddAccessTrackingToStreams < ActiveRecord::Migration[8.0]
  def change
    add_column :streams, :nft_holder, :boolean, default: false
    add_column :streams, :access_tier, :string
    add_column :streams, :quality, :string
    
    add_index :streams, :nft_holder
    add_index :streams, :access_tier
  end
end

