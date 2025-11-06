class AddDeletedAtToUsers < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:users, :deleted_at)
      add_column :users, :deleted_at, :datetime
      add_index :users, :deleted_at
    end
  end
end

