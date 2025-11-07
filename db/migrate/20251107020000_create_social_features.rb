class CreateSocialFeatures < ActiveRecord::Migration[7.1]
  def change
    # Shares table
    create_table :shares do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shareable, polymorphic: true, null: false
      t.string :share_type, null: false # 'social_media', 'copy_link', 'dm', 'email'
      t.json :metadata # Platform, recipient, etc.
      t.timestamps
    end
    
    add_index :shares, [:shareable_type, :shareable_id]
    add_index :shares, :share_type
    
    # User Activity feed
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :activityable, polymorphic: true, null: false
      t.string :activity_type, null: false # 'liked', 'commented', 'shared', 'followed', 'streamed', 'purchased'
      t.json :metadata
      t.timestamps
    end
    
    add_index :user_activities, [:user_id, :created_at]
    add_index :user_activities, [:activityable_type, :activityable_id]
    add_index :user_activities, :activity_type
    
    # Curator Profiles
    create_table :curator_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :display_name
      t.text :bio
      t.string :specialty # Genre or focus area
      t.boolean :verified, default: false
      t.integer :followers_count, default: 0
      t.integer :playlists_count, default: 0
      t.timestamps
    end
    
    add_index :curator_profiles, :verified
    
    # Friend System - extend follows
    add_column :follows, :friendship, :boolean, default: false
    add_column :follows, :status, :string, default: 'active' # 'active', 'pending', 'blocked'
    add_index :follows, :friendship
    add_index :follows, :status
    
    # Collaborative playlists
    add_column :playlists, :collaborative, :boolean, default: false
    add_column :playlists, :public, :boolean, default: false
    add_column :playlists, :followers_count, :integer, default: 0
    
    create_table :playlist_collaborators do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, default: 'editor' # 'owner', 'editor', 'viewer'
      t.timestamps
    end
    
    add_index :playlist_collaborators, [:playlist_id, :user_id], unique: true
    
    # Playlist follows
    create_table :playlist_follows do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :playlist_follows, [:playlist_id, :user_id], unique: true
  end
end

