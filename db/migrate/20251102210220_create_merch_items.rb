class CreateMerchItems < ActiveRecord::Migration[8.0]
  def change
    create_table :merch_items do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.decimal :price
      t.jsonb :variants
      t.jsonb :images
      t.integer :inventory_count

      t.timestamps
    end
  end
end
