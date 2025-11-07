module Api
  module V1
    module Artist
      class DashboardController < BaseController
        before_action :require_artist!
        skip_authorization_check
        
        # GET /api/v1/artist/dashboard
        def index
          artist = current_artist
          
          render json: {
            artist: {
              id: artist.id,
              name: artist.name,
              avatar_url: artist.avatar_url,
              verified: artist.verified
            },
            stats: {
              followers_count: artist.follows.count,
              total_streams: artist.albums.joins(:tracks).joins('INNER JOIN streams ON streams.track_id = tracks.id').count,
              monthly_listeners: artist.albums.joins(:tracks).joins('INNER JOIN streams ON streams.track_id = tracks.id').where('streams.created_at > ?', 30.days.ago).select('DISTINCT streams.user_id').count,
              total_revenue: calculate_total_revenue(artist),
              this_month_revenue: calculate_month_revenue(artist)
            },
            token: artist.artist_token ? {
              id: artist.artist_token.id,
              symbol: artist.artist_token.symbol,
              current_price: artist.artist_token.current_price,
              market_cap: artist.artist_token.market_cap,
              holders_count: artist.artist_token.holders_count
            } : nil,
            content_counts: {
              albums: artist.albums.count,
              tracks: artist.albums.joins(:tracks).count,
              events: artist.events.count,
              upcoming_events: artist.events.upcoming.count,
              livestreams: artist.livestreams.count,
              upcoming_livestreams: artist.livestreams.upcoming.count,
              videos: artist.videos.published.count,
              minis: artist.minis.published.count,
              fan_passes: artist.fan_passes.where(active: true).count,
              merch_items: artist.merch_items.count
            },
            recent_activity: recent_activity(artist),
            upcoming_schedule: upcoming_schedule(artist)
          }
        end
        
        private
        
        def calculate_total_revenue(artist)
          # Sum up all revenue sources
          ticket_sales = artist.events.joins(:ticket_tiers).sum('ticket_tiers.price * ticket_tiers.sold')
          
          # Album-level purchases
          album_sales = artist.albums.joins(:purchases).sum('purchases.price_paid')
          
          # Individual track purchases (join through tracks -> albums to get artist)
          track_sales = Purchase.joins("INNER JOIN tracks ON tracks.id = purchases.purchasable_id AND purchases.purchasable_type = 'Track'")
                               .joins("INNER JOIN albums ON albums.id = tracks.album_id")
                               .where(albums: { artist_id: artist.id })
                               .sum('purchases.price_paid')
          
          # Fan passes: price * number of minted NFTs
          fan_pass_sales = artist.fan_passes.joins(:fan_pass_nfts).sum('fan_passes.price')
          
          # Merch: through order_items
          merch_sales = artist.merch_items.joins(:order_items).sum('order_items.price * order_items.quantity')
          
          ticket_sales + album_sales + track_sales + fan_pass_sales + merch_sales
        end
        
        def calculate_month_revenue(artist)
          start_date = 30.days.ago
          
          # For ticket sales in the last month, count tickets created recently
          ticket_sales = artist.events.joins(ticket_tiers: :tickets).where('tickets.created_at > ?', start_date).sum('ticket_tiers.price')
          
          # Album-level purchases in the last month
          album_sales = artist.albums.joins(:purchases).where('purchases.created_at > ?', start_date).sum('purchases.price_paid')
          
          # Individual track purchases in the last month (join through tracks -> albums to get artist)
          track_sales = Purchase.joins("INNER JOIN tracks ON tracks.id = purchases.purchasable_id AND purchases.purchasable_type = 'Track'")
                               .joins("INNER JOIN albums ON albums.id = tracks.album_id")
                               .where(albums: { artist_id: artist.id })
                               .where('purchases.created_at > ?', start_date)
                               .sum('purchases.price_paid')
          
          # Fan passes minted in the last month
          fan_pass_sales = artist.fan_passes.joins(:fan_pass_nfts).where('fan_pass_nfts.created_at > ?', start_date).sum('fan_passes.price')
          
          # Merch sold in the last month
          merch_sales = artist.merch_items.joins(:order_items).where('order_items.created_at > ?', start_date).sum('order_items.price * order_items.quantity')
          
          ticket_sales + album_sales + track_sales + fan_pass_sales + merch_sales
        end
        
        def recent_activity(artist)
          activities = []
          
          # Recent purchases
          Purchase.where(album_id: artist.albums.pluck(:id))
            .or(Purchase.where(fan_pass_id: artist.fan_passes.pluck(:id)))
            .order(created_at: :desc)
            .limit(5)
            .each do |purchase|
              activities << {
                type: 'purchase',
                description: purchase.album_id ? "Album purchased: #{purchase.album.title}" : "Fan pass purchased: #{purchase.fan_pass.name}",
                user: purchase.user.email || purchase.user.wallet_address,
                amount: purchase.price_sol,
                created_at: purchase.created_at
              }
            end
          
          # Recent followers
          artist.follows.order(created_at: :desc).limit(5).each do |follow|
            activities << {
              type: 'follow',
              description: "New follower",
              user: follow.user.email || follow.user.wallet_address,
              created_at: follow.created_at
            }
          end
          
          # Recent comments
          Comment.where(commentable_type: 'Album', commentable_id: artist.albums.pluck(:id))
            .or(Comment.where(commentable_type: 'Video', commentable_id: artist.videos.pluck(:id)))
            .or(Comment.where(commentable_type: 'Mini', commentable_id: artist.minis.pluck(:id)))
            .order(created_at: :desc)
            .limit(5)
            .each do |comment|
              activities << {
                type: 'comment',
                description: "New comment on #{comment.commentable_type}: \"#{comment.content.truncate(50)}\"",
                user: comment.user.email || comment.user.wallet_address,
                created_at: comment.created_at
              }
            end
          
          activities.sort_by { |a| a[:created_at] }.reverse.take(10)
        end
        
        def upcoming_schedule(artist)
          schedule = []
          
          # Upcoming events
          artist.events.upcoming.order(start_time: :asc).limit(3).each do |event|
            schedule << {
              type: 'event',
              id: event.id,
              title: event.title,
              time: event.start_time,
              venue: event.venue
            }
          end
          
          # Upcoming livestreams
          artist.livestreams.upcoming.order(start_time: :asc).limit(3).each do |stream|
            schedule << {
              type: 'livestream',
              id: stream.id,
              title: stream.title,
              time: stream.start_time
            }
          end
          
          schedule.sort_by { |s| s[:time] }.take(5)
        end
      end
    end
  end
end

