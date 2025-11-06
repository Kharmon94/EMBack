class CreateDirectMessages < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:direct_messages)
      create_table :direct_messages do |t|
        t.references :conversation, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.text :content, null: false
        t.jsonb :attachments, default: []
        t.datetime :read_at
        t.boolean :system_message, default: false

        t.timestamps
      end

      add_index :direct_messages, [:conversation_id, :created_at] unless index_exists?(:direct_messages, [:conversation_id, :created_at])
      add_index :direct_messages, :user_id unless index_exists?(:direct_messages, :user_id)
    end
  end
end

