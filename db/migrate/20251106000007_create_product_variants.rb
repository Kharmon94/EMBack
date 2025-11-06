class CreateProductVariants < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:product_variants)
      create_table :product_variants do |t|
        t.references :merch_item, null: false, foreign_key: true
        t.string :sku, null: false
        t.string :size
        t.string :color
        t.string :material
        t.decimal :price_modifier, precision: 10, scale: 2, default: 0
        t.integer :inventory_count, default: 0
        t.integer :low_stock_threshold, default: 5
        t.boolean :available, default: true

        t.timestamps
      end

      add_index :product_variants, :sku, unique: true unless index_exists?(:product_variants, :sku)
      add_index :product_variants, :merch_item_id unless index_exists?(:product_variants, :merch_item_id)
      add_index :product_variants, :available unless index_exists?(:product_variants, :available)
    end
  end
end

