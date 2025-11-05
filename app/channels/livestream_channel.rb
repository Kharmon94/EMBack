class LivestreamChannel < ApplicationCable::Channel
  def subscribed
    livestream_id = params[:livestream_id]
    
    if livestream_id
      livestream = Livestream.find_by(id: livestream_id)
      
      if livestream && livestream.live?
        stream_from "livestream:#{livestream_id}"
        
        # Increment viewer count
        livestream.increment_viewers!
        
        # Broadcast viewer count update
        ActionCable.server.broadcast(
          "livestream:#{livestream_id}",
          {
            type: 'viewer_count',
            count: livestream.viewer_count
          }
        )
        
        Rails.logger.info("User #{current_user&.id} joined livestream #{livestream_id}")
      else
        reject
      end
    else
      reject
    end
  end

  def unsubscribed
    livestream_id = params[:livestream_id]
    
    if livestream_id
      livestream = Livestream.find_by(id: livestream_id)
      
      if livestream
        # Decrement viewer count
        livestream.decrement_viewers!
        
        # Broadcast viewer count update
        ActionCable.server.broadcast(
          "livestream:#{livestream_id}",
          {
            type: 'viewer_count',
            count: livestream.viewer_count
          }
        )
      end
      
      Rails.logger.info("User #{current_user&.id} left livestream #{livestream_id}")
    end
    
    stop_all_streams
  end
  
  # Receive chat messages
  def speak(data)
    livestream_id = params[:livestream_id]
    message_text = data['message']
    
    return unless current_user && livestream_id && message_text.present?
    
    # Create message record
    message = StreamMessage.create!(
      livestream_id: livestream_id,
      user: current_user,
      content: message_text,
      sent_at: Time.current
    )
    
    # Broadcast to all viewers
    ActionCable.server.broadcast(
      "livestream:#{livestream_id}",
      {
        type: 'chat_message',
        message: {
          id: message.id,
          user: {
            id: current_user.id,
            wallet_address: current_user.wallet_address
          },
          content: message.content,
          sent_at: message.sent_at.iso8601
        }
      }
    )
  end
  
  # Receive tips
  def tip(data)
    livestream_id = params[:livestream_id]
    amount = data['amount']
    mint = data['mint']
    signature = data['signature']
    
    return unless current_user && livestream_id && amount && signature
    
    # Verify transaction
    # TODO: Implement transaction verification with SolanaService
    
    # Create tip message
    message = StreamMessage.create!(
      livestream_id: livestream_id,
      user: current_user,
      content: "Tipped #{amount} #{mint}",
      tip_amount: amount,
      tip_mint: mint,
      sent_at: Time.current
    )
    
    # Broadcast tip
    ActionCable.server.broadcast(
      "livestream:#{livestream_id}",
      {
        type: 'tip',
        message: {
          id: message.id,
          user: {
            id: current_user.id,
            wallet_address: current_user.wallet_address
          },
          amount: amount,
          mint: mint,
          sent_at: message.sent_at.iso8601
        }
      }
    )
  end
end

