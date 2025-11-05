class CreateStreams < ActiveRecord::Migration[8.0]
  def change
    create_table :streams do |t|
      t.references :user, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.integer :duration
      t.datetime :listened_at

      t.timestamps
    end
  end
end
