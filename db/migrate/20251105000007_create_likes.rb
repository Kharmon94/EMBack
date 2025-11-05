class CreateLikes < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:likes)
      create_table :likes do |t|
        t.references :user, null: false, foreign_key: true
        t.references :likeable, polymorphic: true, null: false
        t.timestamps
        
        t.index [:user_id, :likeable_type, :likeable_id], unique: true, name: 'index_likes_on_user_and_likeable'
        t.index [:likeable_type, :likeable_id]
      end
    end
    
    # Add likes_count cache columns to relevant models (check if column exists first)
    add_column :tracks, :likes_count, :integer, default: 0, null: false unless column_exists?(:tracks, :likes_count)
    add_column :albums, :likes_count, :integer, default: 0, null: false unless column_exists?(:albums, :likes_count)
    add_column :livestreams, :likes_count, :integer, default: 0, null: false unless column_exists?(:livestreams, :likes_count)
    add_column :fan_passes, :likes_count, :integer, default: 0, null: false unless column_exists?(:fan_passes, :likes_count)
    
    add_index :tracks, :likes_count unless index_exists?(:tracks, :likes_count)
    add_index :albums, :likes_count unless index_exists?(:albums, :likes_count)
  end
end

