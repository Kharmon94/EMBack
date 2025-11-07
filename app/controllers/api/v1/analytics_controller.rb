module Api
  module V1
    class AnalyticsController < BaseController
      before_action :authenticate_api_user!
      
      # GET /api/v1/analytics/stats
      def stats
        timeframe = params[:timeframe]&.to_sym || :last_30_days
        service = UserStatsService.new(current_user, timeframe)
        
        render json: {
          stats: service.listening_stats.merge(service.viewing_stats).merge(service.engagement_stats),
          timeframe: timeframe
        }
      end
      
      # GET /api/v1/analytics/wrapped
      def wrapped
        year = params[:year]&.to_i || Time.current.year
        timeframe = {
          start: Time.new(year, 1, 1),
          end: Time.new(year, 12, 31, 23, 59, 59)
        }
        
        service = UserStatsService.new(current_user, timeframe)
        
        render json: {
          wrapped: service.wrapped_summary,
          year: year
        }
      end
      
      # GET /api/v1/analytics/history
      def history
        type = params[:type] || 'all' # 'listening', 'viewing', 'all'
        page = params[:page]&.to_i || 1
        per_page = params[:per_page]&.to_i || 50
        
        history_items = []
        
        if type.in?(['listening', 'all'])
          listening = current_user.listening_histories
                                 .includes(track: { album: :artist })
                                 .recent
                                 .limit(per_page)
                                 .offset((page - 1) * per_page)
          
          history_items.concat(listening.map { |lh| listening_history_json(lh) })
        end
        
        if type.in?(['viewing', 'all'])
          viewing = current_user.view_histories
                               .includes(:viewable)
                               .recent
                               .limit(per_page)
                               .offset((page - 1) * per_page)
          
          history_items.concat(viewing.map { |vh| viewing_history_json(vh) })
        end
        
        render json: {
          history: history_items.sort_by { |h| h[:timestamp] }.reverse.take(per_page),
          meta: {
            page: page,
            per_page: per_page,
            type: type
          }
        }
      end
      
      private
      
      def listening_history_json(listening_history)
        {
          id: listening_history.id,
          type: 'listening',
          track: {
            id: listening_history.track.id,
            title: listening_history.track.title,
            artist: listening_history.track.album.artist.name,
            album: listening_history.track.album.title
          },
          duration_played: listening_history.duration_played,
          completed: listening_history.completed,
          source: listening_history.source,
          timestamp: listening_history.created_at
        }
      end
      
      def viewing_history_json(viewing_history)
        {
          id: viewing_history.id,
          type: 'viewing',
          content_type: viewing_history.viewable_type.underscore,
          content: {
            id: viewing_history.viewable.id,
            title: viewing_history.viewable.title,
            artist: viewing_history.viewable.artist.name
          },
          duration_watched: viewing_history.duration_watched,
          watch_percentage: viewing_history.watch_percentage,
          completed: viewing_history.completed,
          timestamp: viewing_history.created_at
        }
      end
    end
  end
end

