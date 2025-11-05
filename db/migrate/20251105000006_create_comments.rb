class CreateComments < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:comments)
      create_table :comments do |t|
        t.references :user, null: false, foreign_key: true
        t.references :commentable, polymorphic: true, null: false
        t.text :content, null: false
        t.integer :likes_count, default: 0, null: false
        t.references :parent, foreign_key: { to_table: :comments }  # For replies
        t.timestamps
        
        t.index [:commentable_type, :commentable_id]
        t.index [:commentable_type, :commentable_id, :created_at]
      end
    end
  end
end

