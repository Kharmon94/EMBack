class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:conversations)
      create_table :conversations do |t|
        t.string :subject
        t.references :order, foreign_key: true
        t.datetime :last_message_at

        t.timestamps
      end

      add_index :conversations, :last_message_at unless index_exists?(:conversations, :last_message_at)
    end
  end
end

