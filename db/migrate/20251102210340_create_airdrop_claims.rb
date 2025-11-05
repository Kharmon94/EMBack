class CreateAirdropClaims < ActiveRecord::Migration[8.0]
  def change
    create_table :airdrop_claims do |t|
      t.references :airdrop, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount
      t.datetime :claimed_at
      t.string :transaction_signature

      t.timestamps
    end
  end
end
