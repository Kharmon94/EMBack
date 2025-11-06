class CreateWishlists < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:wishlists)
      create_table :wishlists do |t|
        t.references :user, null: false, foreign_key: true
        t.string :name, null: false, default: 'My Wishlist'
        t.text :description
        t.boolean :public, default: false
        t.string :share_token

        t.timestamps
      end

      add_index :wishlists, :share_token, unique: true unless index_exists?(:wishlists, :share_token)
      add_index :wishlists, [:user_id, :public] unless index_exists?(:wishlists, [:user_id, :public])
    end
  end
end

