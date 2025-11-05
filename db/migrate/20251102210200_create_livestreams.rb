class CreateLivestreams < ActiveRecord::Migration[8.0]
  def change
    create_table :livestreams do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :status
      t.datetime :start_time
      t.datetime :end_time
      t.integer :viewer_count
      t.decimal :token_gate_amount
      t.string :stream_url

      t.timestamps
    end
  end
end
