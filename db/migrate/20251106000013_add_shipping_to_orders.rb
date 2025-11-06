class AddShippingToOrders < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:orders, :shipping_address)
      add_column :orders, :shipping_address, :jsonb, default: {}
    end
    
    unless column_exists?(:orders, :tracking_number)
      add_column :orders, :tracking_number, :string
    end
    
    unless column_exists?(:orders, :carrier)
      add_column :orders, :carrier, :string
    end
    
    unless column_exists?(:orders, :shipped_at)
      add_column :orders, :shipped_at, :datetime
    end
    
    unless column_exists?(:orders, :delivered_at)
      add_column :orders, :delivered_at, :datetime
    end
    
    unless column_exists?(:orders, :estimated_delivery)
      add_column :orders, :estimated_delivery, :datetime
    end
    
    unless column_exists?(:orders, :blockchain_receipt_url)
      add_column :orders, :blockchain_receipt_url, :string
    end
    
    unless column_exists?(:orders, :notes)
      add_column :orders, :notes, :text
    end
    
    unless index_exists?(:orders, :tracking_number)
      add_index :orders, :tracking_number
    end
  end
end

