class CreateTicketTiers < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_tiers do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.decimal :price
      t.integer :quantity
      t.integer :sold

      t.timestamps
    end
  end
end
