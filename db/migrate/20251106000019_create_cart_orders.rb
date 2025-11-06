class CreateCartOrders < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:cart_orders)
      create_table :cart_orders do |t|
        t.references :user, null: false, foreign_key: true
        t.decimal :total_amount, precision: 10, scale: 2, null: false
        t.integer :status, default: 0, null: false
        t.string :transaction_signature
        t.string :blockchain_receipt_url
        t.jsonb :shipping_address, default: {}
        t.integer :payment_status, default: 0

        t.timestamps
      end

      add_index :cart_orders, :status unless index_exists?(:cart_orders, :status)
      add_index :cart_orders, :transaction_signature unless index_exists?(:cart_orders, :transaction_signature)
    end
  end
end

