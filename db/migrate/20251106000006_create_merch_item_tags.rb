class CreateMerchItemTags < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:merch_item_tags)
      create_table :merch_item_tags do |t|
        t.references :merch_item, null: false, foreign_key: true
        t.references :product_tag, null: false, foreign_key: true

        t.timestamps
      end

      add_index :merch_item_tags, [:merch_item_id, :product_tag_id], unique: true, name: 'index_merch_tags_unique' unless index_exists?(:merch_item_tags, [:merch_item_id, :product_tag_id], name: 'index_merch_tags_unique')
    end
  end
end

