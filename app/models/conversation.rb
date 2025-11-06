class Conversation < ApplicationRecord
  belongs_to :order, optional: true
  has_many :conversation_participants, dependent: :destroy
  has_many :users, through: :conversation_participants
  has_many :direct_messages, dependent: :destroy
  
  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }
  
  def self.between_users(user1_id, user2_id)
    joins(:conversation_participants)
      .where(conversation_participants: { user_id: [user1_id, user2_id] })
      .group('conversations.id')
      .having('COUNT(DISTINCT conversation_participants.user_id) = 2')
      .first
  end
  
  def unread_count_for(user)
    participant = conversation_participants.find_by(user: user)
    return 0 unless participant
    
    direct_messages
      .where('created_at > ?', participant.last_read_at || Time.at(0))
      .where.not(user: user)
      .count
  end
  
  def other_participant(user)
    users.where.not(id: user.id).first
  end
end

