class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :tickets do |t|
      t.references :ticket_tier, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :nft_mint
      t.integer :status
      t.string :qr_code
      t.datetime :purchased_at
      t.datetime :used_at

      t.timestamps
    end
  end
end
