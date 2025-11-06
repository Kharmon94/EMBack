class AddModerationToUsers < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:users, :suspended)
      add_column :users, :suspended, :boolean, default: false
      add_column :users, :suspended_at, :datetime
      add_column :users, :suspension_reason, :text
      add_column :users, :banned, :boolean, default: false
      add_column :users, :banned_at, :datetime
      add_column :users, :ban_reason, :text
      
      add_index :users, :suspended
      add_index :users, :banned
    end
  end
end

