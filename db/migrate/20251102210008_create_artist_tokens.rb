class CreateArtistTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :artist_tokens do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :name
      t.string :symbol
      t.string :mint_address
      t.string :bonding_curve_address
      t.decimal :supply
      t.decimal :market_cap
      t.boolean :graduated
      t.datetime :graduation_date
      t.text :description
      t.string :image_url

      t.timestamps
    end
  end
end
