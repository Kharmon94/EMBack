class CreateGenresAndMoods < ActiveRecord::Migration[7.1]
  def change
    # Genres table with hierarchical support
    create_table :genres do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.references :parent_genre, foreign_key: { to_table: :genres }, null: true
      t.integer :position, default: 0
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :genres, :slug, unique: true
    add_index :genres, :active
    add_index :genres, [:parent_genre_id, :position]
    
    # Moods table
    create_table :moods do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :color_code # Hex color for UI
      t.string :icon # Icon name or emoji
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :moods, :slug, unique: true
    add_index :moods, :active
    
    # Many-to-many: Tracks <-> Genres
    create_table :track_genres do |t|
      t.references :track, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.boolean :primary, default: false
      t.timestamps
    end
    
    add_index :track_genres, [:track_id, :genre_id], unique: true
    add_index :track_genres, :primary
    
    # Many-to-many: Albums <-> Genres
    create_table :album_genres do |t|
      t.references :album, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.boolean :primary, default: false
      t.timestamps
    end
    
    add_index :album_genres, [:album_id, :genre_id], unique: true
    
    # Many-to-many: Tracks <-> Moods
    create_table :track_moods do |t|
      t.references :track, null: false, foreign_key: true
      t.references :mood, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :track_moods, [:track_id, :mood_id], unique: true
    
    # Many-to-many: Videos <-> Genres
    create_table :video_genres do |t|
      t.references :video, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :video_genres, [:video_id, :genre_id], unique: true
    
    # Many-to-many: Minis <-> Moods
    create_table :mini_moods do |t|
      t.references :mini, null: false, foreign_key: true
      t.references :mood, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :mini_moods, [:mini_id, :mood_id], unique: true
    
    # Many-to-many: Events <-> Genres
    create_table :event_genres do |t|
      t.references :event, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :event_genres, [:event_id, :genre_id], unique: true
    
    # User genre preferences
    create_table :user_genre_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true
      t.integer :preference_score, default: 0 # Calculated based on listening history
      t.timestamps
    end
    
    add_index :user_genre_preferences, [:user_id, :genre_id], unique: true
    add_index :user_genre_preferences, [:user_id, :preference_score]
  end
end

