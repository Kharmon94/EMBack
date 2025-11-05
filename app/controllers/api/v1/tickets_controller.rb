module Api
  module V1
    class TicketsController < BaseController
      load_and_authorize_resource
      
      # GET /api/v1/tickets
      def index
        @tickets = current_user.tickets.includes(ticket_tier: { event: :artist })
        
        # Filter by status
        @tickets = @tickets.where(status: params[:status]) if params[:status]
        
        # Filter by event
        @tickets = @tickets.for_event(params[:event_id]) if params[:event_id]
        
        # Order by purchase date
        @tickets = @tickets.order(purchased_at: :desc)
        
        @paginated = paginate(@tickets)
        
        render json: {
          tickets: @paginated.map { |ticket| ticket_json(ticket) },
          meta: pagination_meta(@tickets, @paginated)
        }
      end
      
      # GET /api/v1/tickets/:id
      def show
        render json: { ticket: detailed_ticket_json(@ticket) }
      end
      
      # POST /api/v1/tickets/:id/checkin
      def checkin
        # Only event organizers (artist) or admins can check in tickets
        unless current_user.admin? || @ticket.event.artist.user_id == current_user.id
          return render json: { error: 'Only event organizers can check in tickets' }, status: :forbidden
        end
        
        # Verify QR code
        if params[:qr_code] != @ticket.qr_code
          return render json: { error: 'Invalid QR code' }, status: :unprocessable_entity
        end
        
        # Check if already used
        if @ticket.used?
          return render json: { 
            error: 'Ticket already used',
            used_at: @ticket.used_at
          }, status: :unprocessable_entity
        end
        
        # Check if ticket is valid
        unless @ticket.can_be_used?
          return render json: { error: 'Ticket is not valid' }, status: :unprocessable_entity
        end
        
        # Mark as used
        @ticket.mark_as_used!
        
        render json: {
          message: 'Ticket checked in successfully',
          ticket: detailed_ticket_json(@ticket),
          attendee: {
            wallet_address: @ticket.user.wallet_address
          }
        }
      end
      
      # GET /api/v1/tickets/:id/qr_code
      def qr_code
        require 'rqrcode'
        
        # Generate QR code data
        qr_data = {
          ticket_id: @ticket.id,
          qr_code: @ticket.qr_code,
          event_id: @ticket.event.id,
          issued_at: @ticket.purchased_at.iso8601
        }.to_json
        
        # Generate QR code
        qrcode = RQRCode::QRCode.new(qr_data)
        
        # Return as SVG
        svg = qrcode.as_svg(
          color: '000',
          shape_rendering: 'crispEdges',
          module_size: 6,
          standalone: true
        )
        
        render json: {
          qr_code: @ticket.qr_code,
          qr_svg: svg,
          qr_data: qr_data,
          ticket: ticket_json(@ticket)
        }
      end
      
      private
      
      def ticket_json(ticket)
        {
          id: ticket.id,
          event: {
            id: ticket.event.id,
            title: ticket.event.title,
            venue: ticket.event.venue,
            location: ticket.event.location,
            start_time: ticket.event.start_time,
            end_time: ticket.event.end_time
          },
          tier: {
            id: ticket.ticket_tier.id,
            name: ticket.ticket_tier.name
          },
          qr_code: ticket.qr_code,
          nft_mint: ticket.nft_mint,
          status: ticket.status,
          purchased_at: ticket.purchased_at,
          used_at: ticket.used_at
        }
      end
      
      def detailed_ticket_json(ticket)
        ticket_json(ticket).merge(
          owner: {
            id: ticket.user.id,
            wallet_address: ticket.user.wallet_address
          },
          artist: {
            id: ticket.event.artist.id,
            name: ticket.event.artist.name,
            avatar_url: ticket.event.artist.avatar_url
          }
        )
      end
    end
  end
end

