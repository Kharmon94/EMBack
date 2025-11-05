class AddSocialFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :display_name, :string unless column_exists?(:users, :display_name)
    add_column :users, :bio, :text unless column_exists?(:users, :bio)
    add_column :users, :avatar_url, :string unless column_exists?(:users, :avatar_url)
    add_column :users, :social_links, :jsonb, default: {} unless column_exists?(:users, :social_links)
    
    # Add counter caches for social features
    add_column :users, :followers_count, :integer, default: 0, null: false unless column_exists?(:users, :followers_count)
    add_column :users, :following_count, :integer, default: 0, null: false unless column_exists?(:users, :following_count)
    
    add_index :users, :display_name unless index_exists?(:users, :display_name)
  end
end

