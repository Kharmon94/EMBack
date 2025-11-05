class CreateFanPasses < ActiveRecord::Migration[8.0]
  def change
    create_table :fan_passes do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.decimal :price
      t.jsonb :perks
      t.decimal :token_gate_amount
      t.boolean :active

      t.timestamps
    end
  end
end
