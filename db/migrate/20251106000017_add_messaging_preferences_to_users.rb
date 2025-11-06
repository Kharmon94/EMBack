class AddMessagingPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:users, :accept_messages)
      add_column :users, :accept_messages, :integer, default: 0
      # 0 = everyone, 1 = following_only, 2 = no_one
    end
    
    unless column_exists?(:users, :blocked_user_ids)
      add_column :users, :blocked_user_ids, :integer, array: true, default: []
      add_index :users, :blocked_user_ids, using: 'gin'
    end
  end
end

