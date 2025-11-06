class DirectMessage < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  
  validates :content, presence: true
  
  after_create :update_conversation_timestamp
  after_create_commit :broadcast_message
  
  scope :recent, -> { order(created_at: :asc) }
  scope :unread_for, ->(user) {
    participant = ConversationParticipant.find_by(conversation_id: conversation_id, user: user)
    where('created_at > ?', participant&.last_read_at || Time.at(0))
      .where.not(user: user)
  }
  
  private
  
  def update_conversation_timestamp
    conversation.update_column(:last_message_at, created_at)
  end
  
  def broadcast_message
    # ActionCable broadcast will be handled in controller
  end
end

