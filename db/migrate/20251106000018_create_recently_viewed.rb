class CreateRecentlyViewed < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:recently_viewed_items)
      create_table :recently_viewed_items do |t|
        t.references :user, null: false, foreign_key: true
        t.references :merch_item, null: false, foreign_key: true
        t.datetime :viewed_at, null: false

        t.timestamps
      end

      add_index :recently_viewed_items, [:user_id, :viewed_at] unless index_exists?(:recently_viewed_items, [:user_id, :viewed_at])
      add_index :recently_viewed_items, [:user_id, :merch_item_id], unique: true unless index_exists?(:recently_viewed_items, [:user_id, :merch_item_id])
    end
  end
end

