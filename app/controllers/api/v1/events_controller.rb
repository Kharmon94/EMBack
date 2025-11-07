module Api
  module V1
    class EventsController < BaseController
      include WalletRequired
      
      skip_before_action :authenticate_api_user!, only: [:index, :show], raise: false
      before_action :require_wallet_connection, only: [:purchase_ticket]
      load_and_authorize_resource except: [:index, :show]
      skip_authorization_check only: [:index, :show]
      
      # GET /api/v1/events
      def index
        @events = Event.includes(:artist, :ticket_tiers)
        
        # Filter by artist
        @events = @events.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Filter by status
        @events = @events.where(status: params[:status]) if params[:status]
        
        # Filter upcoming/past
        @events = @events.upcoming if params[:upcoming] == 'true'
        @events = @events.past if params[:past] == 'true'
        
        # Search
        @events = @events.where('title ILIKE ? OR venue ILIKE ?', "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
        
        # ADVANCED FILTERS
        # Genre filter
        @events = @events.joins(:event_genres).where(event_genres: { genre_id: params[:genre_ids] }) if params[:genre_ids].present?
        
        # Location filter
        @events = @events.where('location ILIKE ?', "%#{params[:location]}%") if params[:location].present?
        
        # Date range
        @events = @events.where('start_time >= ?', params[:from_date]) if params[:from_date].present?
        @events = @events.where('start_time <= ?', params[:to_date]) if params[:to_date].present?
        
        # Price range (based on minimum ticket price)
        if params[:min_price].present? || params[:max_price].present?
          @events = @events.joins(:ticket_tiers)
                          .group('events.id')
          @events = @events.having('MIN(ticket_tiers.price) >= ?', params[:min_price].to_f) if params[:min_price].present?
          @events = @events.having('MIN(ticket_tiers.price) <= ?', params[:max_price].to_f) if params[:max_price].present?
        end
        
        # Ticket availability
        @events = @events.joins(:ticket_tiers).where('ticket_tiers.sold < ticket_tiers.total') if params[:tickets_available] == 'true'
        
        # Sort
        @events = @events.order(start_time: params[:sort_desc] == 'true' ? :desc : :asc)
        
        @paginated = paginate(@events)
        
        render json: {
          events: @paginated.map { |event| event_json(event) },
          meta: pagination_meta(@events, @paginated)
        }
      end
      
      # GET /api/v1/events/:id
      def show
        @event = Event.includes(:artist, :ticket_tiers).find(params[:id])
        render json: {
          event: detailed_event_json(@event),
          ticket_tiers: @event.ticket_tiers.map { |tier| tier_json(tier) }
        }
      end
      
      # POST /api/v1/events
      def create
        @event = current_artist.events.build(event_params)
        
        if @event.save
          # Create ticket tiers if provided
          if params[:ticket_tiers].present?
            params[:ticket_tiers].each do |tier_params|
              @event.ticket_tiers.create!(tier_params.permit(:name, :description, :price, :quantity))
            end
          end
          
          render json: {
            event: detailed_event_json(@event),
            message: 'Event created successfully'
          }, status: :created
        else
          render json: { errors: @event.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/events/:id
      def update
        if @event.update(event_params)
          render json: { event: detailed_event_json(@event) }
        else
          render json: { errors: @event.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/events/:id
      def destroy
        @event.update!(status: :cancelled)
        render json: { message: 'Event cancelled successfully' }
      end
      
      # POST /api/v1/events/:id/purchase_ticket
      def purchase_ticket
        authorize! :create, Ticket
        
        tier = @event.ticket_tiers.find(params[:tier_id])
        quantity = params[:quantity].to_i || 1
        
        # Check availability
        if tier.available < quantity
          return render json: { error: 'Not enough tickets available' }, status: :unprocessable_entity
        end
        
        # Verify payment transaction
        signature = params[:transaction_signature]
        unless signature
          return render json: { error: 'Transaction signature required' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction with SolanaService
        
        tickets = []
        quantity.times do
          ticket = Ticket.create!(
            ticket_tier: tier,
            user: current_user,
            nft_mint: params[:nft_mint], # Optional: if minted on-chain
            purchased_at: Time.current
          )
          tickets << ticket
        end
        
        # Update sold count
        tier.increment!(:sold, quantity)
        
        # TODO: Mint NFT tickets on Solana
        
        render json: {
          tickets: tickets.map { |t| ticket_json(t) },
          message: "Successfully purchased #{quantity} ticket(s)",
          total_paid: tier.total_price * quantity
        }, status: :created
      end
      
      private
      
      def event_params
        params.require(:event).permit(
          :title, :description, :venue, :location,
          :start_time, :end_time, :capacity, :status
        )
      end
      
      def event_json(event)
        {
          id: event.id,
          title: event.title,
          description: event.description,
          venue: event.venue,
          location: event.location,
          start_time: event.start_time,
          end_time: event.end_time,
          capacity: event.capacity,
          status: event.status,
          sold_tickets: event.sold_tickets_count,
          is_sold_out: event.is_sold_out?,
          artist: {
            id: event.artist.id,
            name: event.artist.name,
            avatar_url: event.artist.avatar_url
          }
        }
      end
      
      def detailed_event_json(event)
        event_json(event).merge(
          available_capacity: event.available_capacity,
          tiers_count: event.ticket_tiers.count,
          created_at: event.created_at,
          updated_at: event.updated_at
        )
      end
      
      def tier_json(tier)
        {
          id: tier.id,
          name: tier.name,
          description: tier.description,
          price: tier.price,
          quantity: tier.quantity,
          sold: tier.sold,
          available: tier.available,
          sold_out: tier.sold_out?,
          total_price: tier.total_price # All-in pricing
        }
      end
      
      def ticket_json(ticket)
        {
          id: ticket.id,
          event: {
            id: ticket.event.id,
            title: ticket.event.title,
            venue: ticket.event.venue,
            start_time: ticket.event.start_time
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
    end
  end
end

