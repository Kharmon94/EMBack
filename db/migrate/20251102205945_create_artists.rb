class CreateArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :artists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :bio
      t.string :avatar_url
      t.boolean :verified
      t.string :banner_url
      t.string :twitter_handle
      t.string :instagram_handle

      t.timestamps
    end
  end
end
