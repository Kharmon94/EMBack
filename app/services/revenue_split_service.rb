class RevenueSplitService
  # Create a revenue split configuration for an asset (album, event, stream royalties, etc.)
  def create_split(splittable, recipients_data)
    # recipients_data format:
    # [
    #   { wallet_address: "...", percentage: 70, name: "Artist" },
    #   { wallet_address: "...", percentage: 20, name: "Producer" },
    #   { wallet_address: "...", percentage: 10, name: "Collaborator" }
    # ]
    
    # Validate percentages sum to 100
    total_percentage = recipients_data.sum { |r| r[:percentage] }
    raise ArgumentError, "Percentages must sum to 100, got #{total_percentage}" unless total_percentage == 100
    
    # Extract recipients and percentages
    recipients = recipients_data.map { |r| { wallet_address: r[:wallet_address], name: r[:name] } }
    percentages = recipients_data.map { |r| r[:percentage] }
    
    RevenueSplit.create!(
      splittable: splittable,
      recipients: recipients,
      percentages: percentages,
      description: "Revenue split for #{splittable.class.name} ##{splittable.id}"
    )
  end
  
  # Distribute revenue according to split configuration
  def distribute_revenue(revenue_split, total_amount, source_description)
    return [] if total_amount.zero?
    
    distributions = []
    
    revenue_split.recipients.each_with_index do |recipient, index|
      percentage = revenue_split.percentages[index]
      amount = (total_amount * percentage / 100.0).round(8)
      
      # TODO: Execute actual Solana transfer
      # For now, log the distribution
      
      distributions << {
        recipient: recipient,
        percentage: percentage,
        amount: amount,
        source: source_description,
        timestamp: Time.current
      }
      
      Rails.logger.info(
        "Revenue distribution: #{amount} to #{recipient['wallet_address']} " \
        "(#{percentage}%) from #{source_description}"
      )
    end
    
    # TODO: Record distributions in database if needed
    # Could create a RevenueDistribution model to track all payouts
    
    distributions
  end
  
  # Get split configuration for an asset
  def get_split(splittable)
    splittable.revenue_split
  end
  
  # Update split configuration
  def update_split(revenue_split, recipients_data)
    total_percentage = recipients_data.sum { |r| r[:percentage] }
    raise ArgumentError, "Percentages must sum to 100" unless total_percentage == 100
    
    recipients = recipients_data.map { |r| { wallet_address: r[:wallet_address], name: r[:name] } }
    percentages = recipients_data.map { |r| r[:percentage] }
    
    revenue_split.update!(
      recipients: recipients,
      percentages: percentages
    )
  end
  
  # Calculate pending distributions for a period
  def calculate_pending_distributions(splittable, period = 30.days)
    revenue_split = get_split(splittable)
    return [] unless revenue_split
    
    # Calculate revenue based on type
    revenue = case splittable
              when Album
                calculate_album_revenue(splittable, period)
              when Event
                calculate_event_revenue(splittable, period)
              when Livestream
                calculate_livestream_revenue(splittable, period)
              else
                0
              end
    
    return [] if revenue.zero?
    
    # Calculate distribution for each recipient
    revenue_split.recipients.each_with_index.map do |recipient, index|
      percentage = revenue_split.percentages[index]
      amount = (revenue * percentage / 100.0).round(8)
      
      {
        recipient: recipient,
        percentage: percentage,
        amount: amount,
        source: "#{splittable.class.name} ##{splittable.id}",
        period: period
      }
    end
  end
  
  private
  
  def calculate_album_revenue(album, period)
    # Revenue from streams
    stream_revenue = album.tracks.sum do |track|
      StreamingService.calculate_track_revenue(track, period)
    end
    
    # Revenue from sales
    sales_revenue = album.purchases
                        .where("created_at >= ?", period.ago)
                        .sum(:price_paid)
    
    stream_revenue + sales_revenue
  end
  
  def calculate_event_revenue(event, period)
    # Revenue from ticket sales
    event.tickets
         .where("purchased_at >= ?", period.ago)
         .joins(:ticket_tier)
         .sum('ticket_tiers.price')
  end
  
  def calculate_livestream_revenue(livestream, period)
    # Revenue from tips
    livestream.stream_messages
             .where("sent_at >= ?", period.ago)
             .where.not(tip_amount: nil)
             .sum(:tip_amount)
  end
end

