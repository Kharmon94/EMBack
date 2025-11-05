class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status
      t.decimal :total_amount
      t.jsonb :shipping_address
      t.string :tracking_number

      t.timestamps
    end
  end
end
