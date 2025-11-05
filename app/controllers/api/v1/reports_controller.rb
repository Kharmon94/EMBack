module Api
  module V1
    class ReportsController < BaseController
      load_and_authorize_resource
      
      # GET /api/v1/reports
      def index
        @reports = if current_user.admin?
                    Report.all
                  else
                    current_user.reports
                  end
        
        # Filter by status
        @reports = @reports.where(status: params[:status]) if params[:status]
        
        # Filter by type
        @reports = @reports.where(reportable_type: params[:type]) if params[:type]
        
        @reports = @reports.includes(:user, :reportable, :reviewer).order(created_at: :desc)
        @paginated = paginate(@reports)
        
        render json: {
          reports: @paginated.map { |report| report_json(report) },
          meta: pagination_meta(@reports, @paginated)
        }
      end
      
      # GET /api/v1/reports/:id
      def show
        render json: { report: detailed_report_json(@report) }
      end
      
      # POST /api/v1/reports
      def create
        reportable = find_reportable(report_params[:reportable_type], report_params[:reportable_id])
        
        unless reportable
          return render json: { error: 'Invalid reportable' }, status: :bad_request
        end
        
        @report = current_user.reports.build(
          reportable: reportable,
          reason: report_params[:reason]
        )
        
        if @report.save
          # Notify moderators
          # TODO: Send notification to admin team
          
          render json: {
            report: report_json(@report),
            message: 'Report submitted successfully. Our team will review it shortly.'
          }, status: :created
        else
          render json: { errors: @report.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/reports/:id (Admin only)
      def update
        authorize! :manage, @report
        
        if update_params[:status].present?
          @report.status = update_params[:status]
          @report.reviewer = current_user
          @report.reviewed_at = Time.current
        end
        
        if @report.save
          # Take action based on decision
          handle_report_decision(@report) if @report.resolved? && update_params[:action]
          
          render json: { report: detailed_report_json(@report) }
        else
          render json: { errors: @report.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def report_params
        params.require(:report).permit(:reportable_type, :reportable_id, :reason)
      end
      
      def update_params
        params.require(:report).permit(:status, :action)
      end
      
      def find_reportable(type, id)
        case type
        when 'Artist' then Artist.find_by(id: id)
        when 'Album' then Album.find_by(id: id)
        when 'Track' then Track.find_by(id: id)
        when 'Event' then Event.find_by(id: id)
        when 'Livestream' then Livestream.find_by(id: id)
        when 'StreamMessage' then StreamMessage.find_by(id: id)
        when 'User' then User.find_by(id: id)
        else nil
        end
      end
      
      def handle_report_decision(report)
        action = params[:report][:action]
        
        case action
        when 'remove_content'
          # Soft delete or hide the content
          report.reportable.update(hidden: true) if report.reportable.respond_to?(:hidden)
        when 'warn_user'
          # Send warning to user
          # TODO: Implement warning system
        when 'suspend_user'
          # Suspend the user account
          if report.reportable.is_a?(User)
            report.reportable.update(suspended: true, suspended_at: Time.current)
          elsif report.reportable.respond_to?(:user)
            report.reportable.user.update(suspended: true, suspended_at: Time.current)
          end
        when 'ban_user'
          # Permanently ban the user
          if report.reportable.is_a?(User)
            report.reportable.update(banned: true, banned_at: Time.current)
          elsif report.reportable.respond_to?(:user)
            report.reportable.user.update(banned: true, banned_at: Time.current)
          end
        when 'no_action'
          # Mark as dismissed, no action needed
        end
      end
      
      def report_json(report)
        {
          id: report.id,
          reportable_type: report.reportable_type,
          reportable_id: report.reportable_id,
          reason: report.reason,
          status: report.status,
          created_at: report.created_at,
          reporter: {
            id: report.user.id,
            wallet_address: report.user.wallet_address
          }
        }
      end
      
      def detailed_report_json(report)
        report_json(report).merge(
          reviewed_at: report.reviewed_at,
          reviewer: report.reviewer ? {
            id: report.reviewer.id,
            wallet_address: report.reviewer.wallet_address
          } : nil,
          reportable_details: reportable_details(report.reportable)
        )
      end
      
      def reportable_details(reportable)
        case reportable
        when Artist
          { name: reportable.name, type: 'Artist' }
        when Album
          { title: reportable.title, artist: reportable.artist.name, type: 'Album' }
        when Track
          { title: reportable.title, album: reportable.album.title, type: 'Track' }
        when Event
          { title: reportable.title, artist: reportable.artist.name, type: 'Event' }
        when User
          { wallet_address: reportable.wallet_address, role: reportable.role, type: 'User' }
        else
          { type: reportable.class.name }
        end
      end
    end
  end
end

