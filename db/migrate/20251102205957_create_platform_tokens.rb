class CreatePlatformTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_tokens do |t|
      t.string :name
      t.string :symbol
      t.string :mint_address
      t.decimal :total_supply
      t.decimal :circulating_supply
      t.decimal :price_usd
      t.decimal :market_cap

      t.timestamps
    end
  end
end
