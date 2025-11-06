class CreateConversationParticipants < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:conversation_participants)
      create_table :conversation_participants do |t|
        t.references :conversation, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.datetime :last_read_at
        t.boolean :archived, default: false
        t.boolean :muted, default: false

        t.timestamps
      end

      add_index :conversation_participants, [:conversation_id, :user_id], unique: true, name: 'index_conversation_participants_unique' unless index_exists?(:conversation_participants, [:conversation_id, :user_id], name: 'index_conversation_participants_unique')
      add_index :conversation_participants, [:user_id, :archived] unless index_exists?(:conversation_participants, [:user_id, :archived])
    end
  end
end

