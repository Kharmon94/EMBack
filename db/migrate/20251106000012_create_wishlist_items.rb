class CreateWishlistItems < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:wishlist_items)
      create_table :wishlist_items do |t|
        t.references :wishlist, null: false, foreign_key: true
        t.references :merch_item, null: false, foreign_key: true
        t.references :product_variant, foreign_key: true
        t.text :notes

        t.timestamps
      end

      add_index :wishlist_items, [:wishlist_id, :merch_item_id], unique: true unless index_exists?(:wishlist_items, [:wishlist_id, :merch_item_id])
    end
  end
end

