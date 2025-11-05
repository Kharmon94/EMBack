class CreateRevenueSplits < ActiveRecord::Migration[8.0]
  def change
    create_table :revenue_splits do |t|
      t.references :splittable, polymorphic: true, null: false
      t.jsonb :recipients
      t.jsonb :percentages
      t.text :description

      t.timestamps
    end
  end
end
