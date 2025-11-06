class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:reviews)
      create_table :reviews do |t|
        t.references :user, null: false, foreign_key: true
        t.references :merch_item, null: false, foreign_key: true
        t.references :order, foreign_key: true
        t.integer :rating, null: false
        t.string :title
        t.text :content
        t.boolean :verified_purchase, default: false
        t.string :blockchain_proof_url
        t.integer :helpful_count, default: 0
        t.integer :not_helpful_count, default: 0
        t.text :artist_response
        t.datetime :artist_responded_at

        t.timestamps
      end

      add_index :reviews, [:merch_item_id, :user_id], unique: true unless index_exists?(:reviews, [:merch_item_id, :user_id])
      add_index :reviews, :verified_purchase unless index_exists?(:reviews, :verified_purchase)
      add_index :reviews, :rating unless index_exists?(:reviews, :rating)
    end
  end
end

