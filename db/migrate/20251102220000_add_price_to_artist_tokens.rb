class AddPriceToArtistTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :artist_tokens, :price_usd, :decimal, precision: 18, scale: 8, default: 0.0
  end
end

