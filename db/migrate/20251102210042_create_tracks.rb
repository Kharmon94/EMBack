class CreateTracks < ActiveRecord::Migration[8.0]
  def change
    create_table :tracks do |t|
      t.references :album, null: false, foreign_key: true
      t.string :title
      t.integer :duration
      t.string :audio_cid
      t.string :audio_url
      t.string :isrc
      t.integer :track_number
      t.decimal :price
      t.boolean :explicit

      t.timestamps
    end
  end
end
