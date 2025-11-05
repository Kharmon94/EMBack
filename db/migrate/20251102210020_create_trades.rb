class CreateTrades < ActiveRecord::Migration[8.0]
  def change
    create_table :trades do |t|
      t.references :user, null: false, foreign_key: true
      t.references :artist_token, null: false, foreign_key: true
      t.decimal :amount
      t.decimal :price
      t.integer :trade_type
      t.string :transaction_signature

      t.timestamps
    end
  end
end
