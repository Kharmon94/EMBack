class AddParentToOrders < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:orders, :cart_order_id)
      add_reference :orders, :cart_order, foreign_key: true
    end
    
    unless column_exists?(:orders, :shipping_fee)
      add_column :orders, :shipping_fee, :decimal, precision: 10, scale: 2, default: 0
    end
    
    unless column_exists?(:orders, :seller_amount)
      add_column :orders, :seller_amount, :decimal, precision: 10, scale: 2, default: 0
    end
  end
end

