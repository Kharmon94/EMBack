class CreateReviewVotes < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:review_votes)
      create_table :review_votes do |t|
        t.references :review, null: false, foreign_key: true
        t.references :user, null: false, foreign_key: true
        t.boolean :helpful, null: false

        t.timestamps
      end

      add_index :review_votes, [:review_id, :user_id], unique: true unless index_exists?(:review_votes, [:review_id, :user_id])
    end
  end
end

