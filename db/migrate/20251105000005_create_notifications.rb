class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notification_type, null: false  # new_album, new_stream, new_event, etc.
      t.string :title
      t.text :message
      t.jsonb :data, default: {}  # Additional context (album_id, event_id, etc.)
      t.boolean :read, default: false, null: false
      t.datetime :read_at
      t.timestamps
      
      t.index [:user_id, :read]
      t.index [:user_id, :created_at]
      t.index :notification_type
    end
  end
end

