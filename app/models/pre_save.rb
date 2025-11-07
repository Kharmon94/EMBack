class PreSave < ApplicationRecord
  belongs_to :user
  belongs_to :pre_saveable, polymorphic: true
  
  validates :user_id, uniqueness: { scope: [:pre_saveable_type, :pre_saveable_id] }
  validates :release_date, presence: true
  
  scope :pending, -> { where(converted: false) }
  scope :released, -> { where('release_date <= ?', Time.current).where(notified: false) }
  
  # Check for released pre-saves and notify users
  def self.process_released_pre_saves
    released.find_each do |pre_save|
      # Send notification
      Notification.create(
        user: pre_save.user,
        notifiable: pre_save.pre_saveable,
        notification_type: 'pre_save_released',
        message: "#{pre_save.pre_saveable.title} is now available!"
      )
      
      # Mark as notified
      pre_save.update(notified: true)
      
      # Auto-add to library (create purchase if applicable)
      # This is optional - could just notify
    end
  end
end

