class CreateStreamMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :stream_messages do |t|
      t.references :livestream, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.decimal :tip_amount
      t.string :tip_mint
      t.datetime :sent_at

      t.timestamps
    end
  end
end
