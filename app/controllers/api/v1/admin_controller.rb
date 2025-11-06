module Api
  module V1
    class AdminController < BaseController
      before_action :require_admin!
      skip_authorization_check

      # GET /api/v1/admin/dashboard
      def dashboard
        render json: {
          stats: {
            total_users: User.count,
            total_artists: ::Artist.count,
            total_revenue: calculate_total_revenue,
            total_content: total_content_count,
            pending_reports: ::Report.pending.count,
            pending_verifications: ::Artist.where(verification_requested: true, verified: false).count,
            new_users_today: User.where('created_at > ?', 24.hours.ago).count,
            revenue_today: calculate_revenue_since(24.hours.ago)
          },
          growth: {
            users_growth_percentage: calculate_growth_percentage(User, 30.days),
            revenue_growth_percentage: calculate_revenue_growth_percentage(30.days),
            artists_growth_percentage: calculate_growth_percentage(::Artist, 30.days)
          },
          quick_stats: {
            daily_active_users: User.where('updated_at > ?', 24.hours.ago).count,
            monthly_revenue: calculate_revenue_since(30.days.ago),
            content_uploads_24h: content_uploads_last_24h,
            token_trades_24h: ::Trade.where('created_at > ?', 24.hours.ago).count
          },
          recent_activity: recent_activity_feed
        }
      end

      # GET /api/v1/admin/users
      def users
        @users = User.all

        # Filters
        @users = @users.where(role: params[:role]) if params[:role].present?
        @users = @users.where(suspended: true) if params[:status] == 'suspended'
        @users = @users.where(banned: true) if params[:status] == 'banned'
        @users = @users.where(suspended: false, banned: false) if params[:status] == 'active'

        # Search
        if params[:q].present?
          @users = @users.where(
            'email ILIKE ? OR wallet_address ILIKE ?',
            "%#{params[:q]}%", "%#{params[:q]}%"
          )
        end

        @users = @users.includes(:artist).order(created_at: :desc)
        @paginated = paginate(@users)

        render json: {
          users: @paginated.map { |user| admin_user_json(user) },
          meta: pagination_meta(@users, @paginated)
        }
      end

      # PATCH /api/v1/admin/users/:id
      def update_user
        user = User.find(params[:id])
        
        if params[:action] == 'change_role'
          user.update!(role: params[:new_role])
        elsif params[:action] == 'suspend'
          user.update!(
            suspended: true,
            suspended_at: Time.current,
            suspension_reason: params[:reason]
          )
        elsif params[:action] == 'ban'
          user.update!(
            banned: true,
            banned_at: Time.current,
            ban_reason: params[:reason]
          )
        elsif params[:action] == 'unsuspend'
          user.update!(suspended: false, suspended_at: nil, suspension_reason: nil)
        elsif params[:action] == 'unban'
          user.update!(banned: false, banned_at: nil, ban_reason: nil)
        end

        render json: { user: admin_user_json(user), message: 'User updated successfully' }
      rescue => e
        render json: { error: 'Failed to update user', details: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/admin/analytics
      def analytics
        period = parse_period(params[:period])

        render json: {
          user_growth: user_growth_data(period),
          revenue_trends: revenue_trends_data(period),
          content_uploads: content_uploads_data(period),
          engagement: engagement_data(period),
          top_artists: top_artists_by_revenue(10),
          top_content: top_content_by_streams(10),
          revenue_by_category: revenue_by_category_data
        }
      end

      # GET /api/v1/admin/content
      def content
        content_type = params[:type] # albums, tracks, videos, minis, livestreams, merch_items

        items = case content_type
                when 'albums' then ::Album.includes(:artist)
                when 'tracks' then ::Track.includes(album: :artist)
                when 'videos' then ::Video.includes(:artist)
                when 'minis' then ::Mini.includes(:artist)
                when 'livestreams' then ::Livestream.includes(:artist)
                when 'merch_items' then ::MerchItem.includes(:artist)
                else
                  # All content - return summary
                  return render json: {
                    albums: ::Album.count,
                    tracks: ::Track.count,
                    videos: ::Video.count,
                    minis: ::Mini.count,
                    livestreams: ::Livestream.count,
                    merch_items: ::MerchItem.count,
                    recent: recent_content_all_types
                  }
                end

        # Filters
        items = items.where(featured: true) if params[:filter] == 'featured'
        items = items.where(hidden: true) if params[:filter] == 'hidden'

        # Search
        items = items.where('title ILIKE ?', "%#{params[:q]}%") if params[:q].present?

        items = items.order(created_at: :desc)
        @paginated = paginate(items, per_page: 50)

        render json: {
          content: @paginated.map { |item| content_json(item) },
          meta: pagination_meta(items, @paginated)
        }
      end

      # POST /api/v1/admin/content/:type/:id/feature
      def feature_content
        item = find_content_item(params[:type], params[:id])
        item.update!(featured: true)
        render json: { message: 'Content featured successfully', item: content_json(item) }
      rescue => e
        render json: { error: 'Failed to feature content', details: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/admin/content/:type/:id/remove
      def remove_content
        item = find_content_item(params[:type], params[:id])
        item.update!(hidden: true, removal_reason: params[:reason])
        render json: { message: 'Content removed successfully' }
      rescue => e
        render json: { error: 'Failed to remove content', details: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/admin/revenue
      def revenue
        render json: {
          total_revenue: calculate_total_revenue,
          revenue_by_source: {
            tickets: calculate_ticket_revenue,
            albums: calculate_album_revenue,
            tokens: calculate_token_revenue,
            fan_passes: calculate_fan_pass_revenue,
            merch: calculate_merch_revenue
          },
          fee_breakdown: {
            dev_fee: calculate_dev_fees,
            platform_fee: calculate_platform_fees,
            artist_payouts: calculate_artist_payouts
          },
          monthly_revenue: monthly_revenue_data,
          recent_transactions: recent_transactions(50)
        }
      end

      # POST /api/v1/admin/verification/:id/approve
      def approve_verification
        artist = ::Artist.find(params[:id])
        artist.update!(verified: true, verification_requested: false)
        
        # Notify artist
        ::Notification.create!(
          user: artist.user,
          notification_type: 'verification_approved',
          message: 'Congratulations! Your artist account has been verified.'
        )

        render json: { message: 'Verification approved', artist: { id: artist.id, name: artist.name, verified: true } }
      rescue => e
        render json: { error: 'Failed to approve verification', details: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/admin/verification/:id/reject
      def reject_verification
        artist = ::Artist.find(params[:id])
        artist.update!(verification_requested: false)
        
        # Notify artist
        ::Notification.create!(
          user: artist.user,
          notification_type: 'verification_rejected',
          message: "Your verification request was not approved. Reason: #{params[:reason]}"
        )

        render json: { message: 'Verification rejected' }
      rescue => e
        render json: { error: 'Failed to reject verification', details: e.message }, status: :unprocessable_entity
      end

      private

      def require_admin!
        unless current_user&.admin?
          render json: { error: 'Admin access required' }, status: :forbidden
        end
      end

      def calculate_total_revenue
        # Simplified: Just sum all purchases (covers tickets, albums, fan passes, etc)
        ::Purchase.sum(:price_paid) || 0
      end

      def calculate_revenue_since(time)
        ::Purchase.where('created_at > ?', time).sum(:price_paid) || 0
      end

      def total_content_count
        ::Album.count + ::Track.count + ::Video.count + ::Mini.count + ::Livestream.count + ::MerchItem.count
      end

      def content_uploads_last_24h
        {
          albums: ::Album.where('created_at > ?', 24.hours.ago).count,
          tracks: ::Track.where('created_at > ?', 24.hours.ago).count,
          videos: ::Video.where('created_at > ?', 24.hours.ago).count,
          minis: ::Mini.where('created_at > ?', 24.hours.ago).count
        }
      end

      def calculate_growth_percentage(model, period)
        current_count = model.where('created_at > ?', period.ago).count
        previous_count = model.where('created_at BETWEEN ? AND ?', period.ago * 2, period.ago).count
        
        return 0 if previous_count.zero?
        ((current_count - previous_count).to_f / previous_count * 100).round(1)
      end

      def calculate_revenue_growth_percentage(period)
        current_revenue = calculate_revenue_since(period.ago)
        previous_start = period.ago * 2
        previous_end = period.ago
        
        previous_revenue = ::Purchase.where('created_at BETWEEN ? AND ?', previous_start, previous_end).sum(:price_paid) || 0
        
        return 0 if previous_revenue.zero?
        ((current_revenue - previous_revenue) / previous_revenue * 100).round(1)
      end

      def recent_activity_feed
        activities = []
        
        # Recent signups
        User.order(created_at: :desc).limit(5).each do |user|
          activities << {
            type: 'signup',
            description: "New #{user.role} signed up",
            user: user.email || user.wallet_address,
            timestamp: user.created_at
          }
        end

        # Recent content
        ::Album.order(created_at: :desc).limit(3).each do |album|
          activities << {
            type: 'upload',
            description: "::Album uploaded: #{album.title}",
            user: album.artist.name,
            timestamp: album.created_at
          }
        end

        # Recent reports
        ::Report.pending.order(created_at: :desc).limit(3).each do |report|
          activities << {
            type: 'report',
            description: "New report: #{report.reportable_type}",
            user: report.user.email || report.user.wallet_address,
            timestamp: report.created_at
          }
        end

        activities.sort_by { |a| a[:timestamp] }.reverse.take(15)
      end

      def user_growth_data(period)
        days = period / 1.day
        (0..days.to_i).map do |day_offset|
          date = day_offset.days.ago.to_date
          {
            date: date,
            count: User.where('DATE(created_at) = ?', date).count
          }
        end.reverse
      end

      def revenue_trends_data(period)
        days = period / 1.day
        (0..days.to_i).map do |day_offset|
          date = day_offset.days.ago.to_date
          {
            date: date,
            amount: calculate_revenue_for_date(date)
          }
        end.reverse
      end

      def calculate_revenue_for_date(date)
        start_time = date.beginning_of_day
        end_time = date.end_of_day
        
        ::Purchase.where('created_at BETWEEN ? AND ?', start_time, end_time).sum(:price_paid) || 0
      end

      def content_uploads_data(period)
        start_date = period.ago
        {
          albums: ::Album.where('created_at > ?', start_date).group_by_week(:created_at).count,
          tracks: ::Track.where('created_at > ?', start_date).group_by_week(:created_at).count,
          videos: ::Video.where('created_at > ?', start_date).group_by_week(:created_at).count,
          minis: ::Mini.where('created_at > ?', start_date).group_by_week(:created_at).count
        }
      end

      def engagement_data(period)
        start_date = period.ago
        {
          streams: Stream.where('created_at > ?', start_date).group_by_day(:created_at).count,
          video_views: ::VideoView.where('created_at > ?', start_date).group_by_day(:created_at).count,
          mini_views: ::MiniView.where('created_at > ?', start_date).group_by_day(:created_at).count,
          likes: ::Like.where('created_at > ?', start_date).group_by_day(:created_at).count
        }
      end

      def top_artists_by_revenue(limit)
        ::Artist.joins('LEFT JOIN events ON events.artist_id = artists.id')
              .joins('LEFT JOIN tickets ON tickets.event_id = events.id')
              .joins('LEFT JOIN ticket_tiers ON ticket_tiers.id = tickets.ticket_tier_id')
              .select('artists.*, SUM(ticket_tiers.price * tickets.quantity) as total_revenue')
              .group('artists.id')
              .order('total_revenue DESC NULLS LAST')
              .limit(limit)
              .map do |artist|
          {
            id: artist.id,
            name: artist.name,
            revenue: artist.total_revenue || 0,
            followers: artist.follows.count
          }
        end
      end

      def top_content_by_streams(limit)
        ::Track.joins(:streams)
             .select('tracks.*, albums.title as album_title, artists.name as artist_name, COUNT(streams.id) as stream_count')
             .joins(album: :artist)
             .group('tracks.id, albums.title, artists.name')
             .order('stream_count DESC')
             .limit(limit)
             .map do |track|
          {
            id: track.id,
            title: track.title,
            artist: track.artist_name,
            album: track.album_title,
            streams: track.stream_count
          }
        end
      end

      def revenue_by_category_data
        {
          tickets: calculate_ticket_revenue,
          albums: calculate_album_revenue,
          tokens: calculate_token_revenue,
          fan_passes: calculate_fan_pass_revenue,
          merch: calculate_merch_revenue
        }
      end

      def calculate_ticket_revenue
        ::Purchase.where(purchasable_type: 'Ticket').sum(:price_paid) || 0
      end

      def calculate_album_revenue
        ::Purchase.where(purchasable_type: 'Album').sum(:price_paid) || 0
      end

      def calculate_token_revenue
        ::Purchase.where(purchasable_type: 'ArtistToken').sum(:price_paid) || 0
      end

      def calculate_fan_pass_revenue
        ::Purchase.where(purchasable_type: 'FanPass').sum(:price_paid) || 0
      end

      def calculate_merch_revenue
        ::Order.sum(:total_amount) || 0
      end

      def calculate_dev_fees
        # 20% of all revenue
        calculate_total_revenue * 0.20
      end

      def calculate_platform_fees
        # Platform fees from trades, etc
        ::Trade.sum(:platform_fee_amount) || 0
      end

      def calculate_artist_payouts
        # 80% of revenue minus fees
        calculate_total_revenue * 0.80
      end

      def monthly_revenue_data
        (0..11).map do |month_offset|
          start_date = month_offset.months.ago.beginning_of_month
          end_date = month_offset.months.ago.end_of_month
          {
            month: start_date.strftime('%b %Y'),
            amount: calculate_revenue_between(start_date, end_date)
          }
        end.reverse
      end

      def calculate_revenue_between(start_time, end_time)
        ticket_revenue = ::Event.joins(:tickets).joins(:ticket_tiers).where('tickets.created_at BETWEEN ? AND ?', start_time, end_time).sum('ticket_tiers.price * tickets.quantity')
        album_revenue = ::Purchase.where.not(album_id: nil).where('created_at BETWEEN ? AND ?', start_time, end_time).sum(:price_sol)
        fan_pass_revenue = ::Purchase.where.not(fan_pass_id: nil).where('created_at BETWEEN ? AND ?', start_time, end_time).sum(:price_sol)
        merch_revenue = ::Order.where('created_at BETWEEN ? AND ?', start_time, end_time).sum(:total_price)
        
        ticket_revenue + album_revenue + fan_pass_revenue + merch_revenue
      end

      def recent_transactions(limit)
        transactions = []

        ::Purchase.includes(:user, :album, :fan_pass).order(created_at: :desc).limit(limit / 2).each do |purchase|
          transactions << {
            type: purchase.album ? '::Album ::Purchase' : 'Fan Pass ::Purchase',
            amount: purchase.price_sol,
            artist: purchase.album ? purchase.album.artist.name : purchase.fan_pass.artist.name,
            user: purchase.user.email || purchase.user.wallet_address,
            timestamp: purchase.created_at
          }
        end

        ::Order.includes(:user).order(created_at: :desc).limit(limit / 4).each do |order|
          transactions << {
            type: 'Merch ::Order',
            amount: order.total_price,
            user: order.user.email || order.user.wallet_address,
            timestamp: order.created_at
          }
        end

        transactions.sort_by { |t| t[:timestamp] }.reverse.take(limit)
      end

      def recent_content_all_types
        content = []
        
        ::Album.order(created_at: :desc).limit(3).each do |item|
          content << { type: '::Album', id: item.id, title: item.title, artist: item.artist.name, created_at: item.created_at }
        end
        
        ::Video.includes(:artist).order(created_at: :desc).limit(3).each do |item|
          content << { type: '::Video', id: item.id, title: item.title, artist: item.artist.name, created_at: item.created_at }
        end
        
        ::Mini.includes(:artist).order(created_at: :desc).limit(3).each do |item|
          content << { type: '::Mini', id: item.id, title: item.title, artist: item.artist.name, created_at: item.created_at }
        end
        
        content.sort_by { |c| c[:created_at] }.reverse.take(10)
      end

      def parse_period(period_param)
        case period_param
        when '7d' then 7.days
        when '30d' then 30.days
        when '90d' then 90.days
        else 30.days
        end
      end

      def find_content_item(type, id)
        case type
        when 'albums' then ::Album.find(id)
        when 'tracks' then ::Track.find(id)
        when 'videos' then ::Video.find(id)
        when 'minis' then ::Mini.find(id)
        when 'livestreams' then ::Livestream.find(id)
        when 'merch_items' then ::MerchItem.find(id)
        else
          raise ActiveRecord::RecordNotFound
        end
      end

      def admin_user_json(user)
        {
          id: user.id,
          email: user.email,
          wallet_address: user.wallet_address,
          role: user.role,
          suspended: user.suspended || false,
          banned: user.banned || false,
          suspension_reason: user.suspension_reason,
          ban_reason: user.ban_reason,
          created_at: user.created_at,
          last_sign_in_at: user.updated_at, # Using updated_at as proxy for activity
          artist: user.artist ? { id: user.artist.id, name: user.artist.name, verified: user.artist.verified } : nil
        }
      end

      def content_json(item)
        {
          id: item.id,
          type: item.class.name,
          title: item.title || item.name,
          artist: item.respond_to?(:artist) ? { id: item.artist.id, name: item.artist.name } : nil,
          created_at: item.created_at,
          featured: item.respond_to?(:featured) ? item.featured : false,
          hidden: item.respond_to?(:hidden) ? item.hidden : false,
          thumbnail_url: item.respond_to?(:thumbnail_url) ? item.thumbnail_url : (item.respond_to?(:cover_url) ? item.cover_url : nil)
        }
      end
    end
  end
end

