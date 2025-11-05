class TradesChannel < ApplicationCable::Channel
  def subscribed
    token_id = params[:token_id]
    if token_id
      stream_from "trades:#{token_id}"
      Rails.logger.info("User subscribed to trades for token #{token_id}")
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end
end

