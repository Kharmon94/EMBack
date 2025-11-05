class CreateLiquidityPools < ActiveRecord::Migration[8.0]
  def change
    create_table :liquidity_pools do |t|
      t.references :artist_token, null: false, foreign_key: true
      t.integer :platform
      t.string :pool_address
      t.decimal :reserve_token
      t.decimal :reserve_sol
      t.decimal :tvl
      t.decimal :volume_24h

      t.timestamps
    end
  end
end
