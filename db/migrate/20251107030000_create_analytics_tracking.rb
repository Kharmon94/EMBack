class CreateAnalyticsTracking < ActiveRecord::Migration[7.1]
  def change
    # Listening History - detailed playback sessions
    create_table :listening_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.references :album, foreign_key: true
      t.references :playlist, foreign_key: true
      t.integer :duration_played # seconds actually played
      t.boolean :completed, default: false
      t.string :source # 'album', 'playlist', 'radio', 'search', 'recommendation'
      t.string :device_type # 'mobile', 'desktop', 'tablet'
      t.json :metadata
      t.timestamps
    end
    
    add_index :listening_histories, [:user_id, :created_at]
    add_index :listening_histories, [:track_id, :created_at]
    add_index :listening_histories, :completed
    
    # View History - videos and minis
    create_table :view_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :viewable, polymorphic: true, null: false # Video or Mini
      t.integer :duration_watched # seconds watched
      t.integer :total_duration # total duration of content
      t.boolean :completed, default: false
      t.integer :watch_percentage # 0-100
      t.string :source # 'feed', 'search', 'recommendation', 'artist_page'
      t.string :device_type
      t.json :metadata
      t.timestamps
    end
    
    add_index :view_histories, [:user_id, :created_at]
    add_index :view_histories, [:viewable_type, :viewable_id]
    add_index :view_histories, :completed
    
    # Search History
    create_table :search_histories do |t|
      t.references :user, foreign_key: true
      t.string :query, null: false
      t.string :search_type # 'all', 'music', 'videos', 'artists', etc.
      t.integer :results_count
      t.boolean :clicked_result, default: false
      t.string :clicked_result_type
      t.bigint :clicked_result_id
      t.timestamps
    end
    
    add_index :search_histories, [:user_id, :created_at]
    add_index :search_histories, :query
    
    # Recently Played - quick access to recent content
    create_table :recently_playeds do |t|
      t.references :user, null: false, foreign_key: true
      t.references :playable, polymorphic: true, null: false
      t.timestamps
    end
    
    add_index :recently_playeds, [:user_id, :created_at]
    add_index :recently_playeds, [:playable_type, :playable_id]
    add_index :recently_playeds, [:user_id, :playable_type, :playable_id], unique: true, name: 'index_recently_played_unique'
  end
end

