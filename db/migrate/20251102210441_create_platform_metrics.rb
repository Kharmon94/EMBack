class CreatePlatformMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_metrics do |t|
      t.date :date
      t.decimal :daily_volume
      t.decimal :fees_collected
      t.decimal :tokens_burned
      t.integer :active_users
      t.integer :new_tokens
      t.integer :total_streams

      t.timestamps
    end
  end
end
