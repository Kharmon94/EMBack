class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:videos)
      create_table :videos do |t|
        t.references :artist, null: false, foreign_key: true
        t.string :title, null: false
        t.text :description
        t.integer :duration  # in seconds
        t.string :video_url
        t.string :thumbnail_url
        t.decimal :price, precision: 10, scale: 2, default: 0
        t.integer :access_tier, default: 0, null: false  # free, preview_only, nft_required, paid
        t.integer :preview_duration, default: 60  # seconds for preview
        t.integer :views_count, default: 0, null: false
        t.integer :likes_count, default: 0, null: false
        t.boolean :published, default: false, null: false
        t.datetime :published_at
        t.timestamps
      end
      
      add_index :videos, :artist_id unless index_exists?(:videos, :artist_id)
      add_index :videos, :access_tier unless index_exists?(:videos, :access_tier)
      add_index :videos, [:artist_id, :published] unless index_exists?(:videos, [:artist_id, :published])
      add_index :videos, :published_at unless index_exists?(:videos, :published_at)
      add_index :videos, :views_count unless index_exists?(:videos, :views_count)
      add_index :videos, :likes_count unless index_exists?(:videos, :likes_count)
    end
    
    # Video views tracking (analytics)
    unless table_exists?(:video_views)
      create_table :video_views do |t|
        t.references :video, null: false, foreign_key: true
        t.references :user, foreign_key: true
        t.integer :watched_duration  # seconds watched
        t.boolean :completed, default: false
        t.boolean :nft_holder, default: false
        t.string :access_tier  # free, preview, premium, paid
        t.timestamps
      end
      
      add_index :video_views, [:video_id, :user_id] unless index_exists?(:video_views, [:video_id, :user_id])
      add_index :video_views, :nft_holder unless index_exists?(:video_views, :nft_holder)
      add_index :video_views, :completed unless index_exists?(:video_views, :completed)
      add_index :video_views, :created_at unless index_exists?(:video_views, :created_at)
    end
  end
end
