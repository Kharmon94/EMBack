class AddNotificationPreferencesToUsers < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:users, :notification_preferences)
      add_column :users, :notification_preferences, :jsonb, default: {
        email_enabled: true,
        purchases: true,
        followers: true,
        comments: true,
        likes: true,
        livestreams: true
      }
    end
  end
end

