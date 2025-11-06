class CreateProductCategories < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:product_categories)
      create_table :product_categories do |t|
        t.string :name, null: false
        t.string :slug, null: false
        t.text :description
        t.integer :parent_id
        t.string :image_url
        t.integer :position, default: 0
        t.boolean :active, default: true

        t.timestamps
      end

      add_index :product_categories, :slug, unique: true unless index_exists?(:product_categories, :slug)
      add_index :product_categories, :parent_id unless index_exists?(:product_categories, :parent_id)
      add_index :product_categories, :active unless index_exists?(:product_categories, :active)
    end
  end
end

