class CreateProductTags < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:product_tags)
      create_table :product_tags do |t|
        t.string :name, null: false
        t.string :slug, null: false
        t.text :description

        t.timestamps
      end

      add_index :product_tags, :slug, unique: true unless index_exists?(:product_tags, :slug)
    end
  end
end

