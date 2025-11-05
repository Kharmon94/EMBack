class CreateAirdrops < ActiveRecord::Migration[8.0]
  def change
    create_table :airdrops do |t|
      t.references :artist, null: false, foreign_key: true
      t.references :artist_token, null: false, foreign_key: true
      t.string :merkle_root
      t.string :program_address
      t.decimal :total_amount
      t.decimal :claimed_amount
      t.datetime :start_date
      t.datetime :end_date

      t.timestamps
    end
  end
end
