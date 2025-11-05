class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :venue
      t.string :location
      t.datetime :start_time
      t.datetime :end_time
      t.integer :capacity
      t.integer :status

      t.timestamps
    end
  end
end
