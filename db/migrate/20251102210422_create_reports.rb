class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reportable, polymorphic: true, null: false
      t.text :reason
      t.integer :status, default: 0
      t.datetime :reviewed_at
      t.references :reviewer, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :reports, [:reportable_type, :reportable_id]
    add_index :reports, :status
  end
end
