class CreateAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :albums do |t|
      t.references :artist, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :cover_cid
      t.string :cover_url
      t.decimal :price
      t.string :upc
      t.date :release_date

      t.timestamps
    end
  end
end
