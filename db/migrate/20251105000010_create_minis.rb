class CreateMinis < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:minis)
      create_table :minis do |t|
        t.references :artist, null: false, foreign_key: true
        t.string :title, null: false
        t.text :description
        t.integer :duration, null: false  # in seconds, max 120
        t.string :video_url
        t.string :thumbnail_url
        t.decimal :price, precision: 10, scale: 2, default: 0
        t.integer :access_tier, default: 0, null: false  # free, preview_only, nft_required, paid
        t.integer :preview_duration, default: 30  # seconds for preview
        t.integer :views_count, default: 0, null: false
        t.integer :likes_count, default: 0, null: false
        t.integer :shares_count, default: 0, null: false
        t.string :aspect_ratio, default: '9:16'
        t.boolean :published, default: false, null: false
        t.datetime :published_at
        t.timestamps
      end
      
      add_index :minis, :artist_id unless index_exists?(:minis, :artist_id)
      add_index :minis, :access_tier unless index_exists?(:minis, :access_tier)
      add_index :minis, [:artist_id, :published] unless index_exists?(:minis, [:artist_id, :published])
      add_index :minis, :published_at unless index_exists?(:minis, :published_at)
      add_index :minis, :views_count unless index_exists?(:minis, :views_count)
      add_index :minis, :likes_count unless index_exists?(:minis, :likes_count)
      add_index :minis, :shares_count unless index_exists?(:minis, :shares_count)
      
      # Add check constraint for max duration of 120 seconds
      execute <<-SQL
        ALTER TABLE minis
        ADD CONSTRAINT mini_duration_limit
        CHECK (duration > 0 AND duration <= 120);
      SQL
    end
    
    # Mini views tracking (analytics)
    unless table_exists?(:mini_views)
      create_table :mini_views do |t|
        t.references :mini, null: false, foreign_key: true
        t.references :user, foreign_key: true
        t.integer :watched_duration  # seconds watched
        t.boolean :completed, default: false
        t.boolean :nft_holder, default: false
        t.string :access_tier  # free, preview, premium, paid
        t.timestamps
      end
      
      add_index :mini_views, [:mini_id, :user_id] unless index_exists?(:mini_views, [:mini_id, :user_id])
      add_index :mini_views, :nft_holder unless index_exists?(:mini_views, :nft_holder)
      add_index :mini_views, :completed unless index_exists?(:mini_views, :completed)
      add_index :mini_views, :created_at unless index_exists?(:mini_views, :created_at)
    end
  end
end
