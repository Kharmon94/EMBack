class AddPlayerAndContentFeatures < ActiveRecord::Migration[7.1]
  def change
    # Lyrics for tracks
    add_column :tracks, :lyrics, :text
    
    # Credits for tracks and albums
    add_column :tracks, :credits, :jsonb, default: {}
    add_column :albums, :credits, :jsonb, default: {}
    
    # Custom playlist artwork
    add_column :playlists, :custom_cover_url, :string
    
    # Hashtags for minis
    add_column :minis, :hashtags, :string, array: true, default: []
    add_index :minis, :hashtags, using: :gin
    
    # Pre-saves table
    create_table :pre_saves do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pre_saveable, polymorphic: true, null: false
      t.datetime :release_date
      t.boolean :notified, default: false
      t.boolean :converted, default: false # Auto-added to library
      t.timestamps
    end
    
    add_index :pre_saves, [:user_id, :pre_saveable_type, :pre_saveable_id], unique: true, name: 'index_pre_saves_unique'
    add_index :pre_saves, [:release_date, :notified]
    
    # Playlist folders
    create_table :playlist_folders do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color_code
      t.integer :position, default: 0
      t.timestamps
    end
    
    add_index :playlist_folders, [:user_id, :position]
    
    # Add folder reference to playlists
    add_reference :playlists, :playlist_folder, foreign_key: true
    
    # Video/Mini genres associations (already done for tracks/albums/events)
    create_table :video_moods do |t|
      t.references :video, null: false, foreign_key: true
      t.references :mood, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :video_moods, [:video_id, :mood_id], unique: true
    
    create_table :mini_genres do |t|
      t.references :mini, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :mini_genres, [:mini_id, :genre_id], unique: true
  end
end

