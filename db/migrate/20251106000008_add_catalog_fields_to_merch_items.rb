class AddCatalogFieldsToMerchItems < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:merch_items, :category_id)
      add_reference :merch_items, :product_category, foreign_key: true
    end
    
    unless column_exists?(:merch_items, :sku)
      add_column :merch_items, :sku, :string
      add_index :merch_items, :sku, unique: true
    end
    
    unless column_exists?(:merch_items, :brand)
      add_column :merch_items, :brand, :string
    end
    
    unless column_exists?(:merch_items, :featured)
      add_column :merch_items, :featured, :boolean, default: false
      add_index :merch_items, :featured
    end
    
    unless column_exists?(:merch_items, :rating_average)
      add_column :merch_items, :rating_average, :decimal, precision: 3, scale: 2, default: 0
    end
    
    unless column_exists?(:merch_items, :rating_count)
      add_column :merch_items, :rating_count, :integer, default: 0
    end
    
    unless column_exists?(:merch_items, :view_count)
      add_column :merch_items, :view_count, :integer, default: 0
    end
    
    unless column_exists?(:merch_items, :purchase_count)
      add_column :merch_items, :purchase_count, :integer, default: 0
    end
    
    unless column_exists?(:merch_items, :low_stock_threshold)
      add_column :merch_items, :low_stock_threshold, :integer, default: 5
    end
    
    unless column_exists?(:merch_items, :weight)
      add_column :merch_items, :weight, :decimal, precision: 8, scale: 2
    end
    
    unless column_exists?(:merch_items, :dimensions)
      add_column :merch_items, :dimensions, :jsonb, default: {}
    end
    
    unless column_exists?(:merch_items, :token_gated)
      add_column :merch_items, :token_gated, :boolean, default: false
      add_column :merch_items, :minimum_tokens_required, :integer, default: 0
    end
    
    unless column_exists?(:merch_items, :limited_edition)
      add_column :merch_items, :limited_edition, :boolean, default: false
      add_column :merch_items, :edition_size, :integer
      add_column :merch_items, :edition_number, :integer
    end
  end
end

