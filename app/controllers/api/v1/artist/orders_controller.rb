module Api
  module V1
    module Artist
      class OrdersController < BaseController
        before_action :require_artist_role
        
        # GET /api/v1/artist/orders
        def index
          @orders = ::Order.for_artist(current_artist.id)
                          .includes(:user, order_items: :merch_item)
                          .recent
          
          # Filter by status
          @orders = @orders.where(status: params[:status]) if params[:status].present?
          
          # Filter by date range
          @orders = @orders.where('created_at >= ?', params[:from_date]) if params[:from_date].present?
          @orders = @orders.where('created_at <= ?', params[:to_date]) if params[:to_date].present?
          
          # Search by order ID or customer
          if params[:q].present?
            @orders = @orders.joins(:user).where(
              'orders.id::text LIKE ? OR users.email ILIKE ?',
              "%#{params[:q]}%", "%#{params[:q]}%"
            )
          end
          
          @paginated = paginate(@orders.distinct)
          
          render json: {
            orders: @paginated.map { |order| order_list_json(order) },
            meta: pagination_meta(@orders, @paginated),
            stats: calculate_order_stats
          }
        end
        
        # GET /api/v1/artist/orders/:id
        def show
          @order = ::Order.for_artist(current_artist.id).includes(:user, order_items: :merch_item).find(params[:id])
          
          render json: {
            order: detailed_order_json(@order)
          }
        end
        
        # PATCH /api/v1/artist/orders/:id/update_status
        def update_status
          @order = ::Order.for_artist(current_artist.id).find(params[:id])
          
          case params[:status]
          when 'processing'
            @order.update!(status: :processing)
          when 'shipped'
            @order.mark_as_shipped!(params[:tracking_number], params[:carrier])
          when 'delivered'
            @order.update!(status: :delivered, delivered_at: Time.current)
          when 'cancelled'
            @order.update!(status: :cancelled)
          end
          
          render json: { 
            order: detailed_order_json(@order),
            message: 'Order status updated'
          }
        end
        
        # POST /api/v1/artist/orders/:id/add_note
        def add_note
          @order = ::Order.for_artist(current_artist.id).find(params[:id])
          @order.update!(notes: params[:note])
          
          render json: { 
            order: detailed_order_json(@order),
            message: 'Note added'
          }
        end
        
        # GET /api/v1/artist/orders/export
        def export
          @orders = ::Order.for_artist(current_artist.id).recent
          
          # Apply same filters as index
          @orders = @orders.where(status: params[:status]) if params[:status].present?
          @orders = @orders.where('created_at >= ?', params[:from_date]) if params[:from_date].present?
          @orders = @orders.where('created_at <= ?', params[:to_date]) if params[:to_date].present?
          
          csv_data = generate_orders_csv(@orders)
          
          send_data csv_data, filename: "orders_#{Date.today}.csv", type: 'text/csv'
        end
        
        private
        
        def require_artist_role
          unless current_user&.artist?
            render json: { error: 'Artist access required' }, status: :forbidden
          end
        end
        
        def calculate_order_stats
          orders = ::Order.for_artist(current_artist.id)
          
          {
            total_orders: orders.count,
            total_revenue: orders.where(status: [:paid, :processing, :shipped, :delivered]).sum(:total_amount),
            pending_fulfillment: orders.pending_fulfillment.count,
            shipped_this_week: orders.where('shipped_at >= ?', 1.week.ago).count,
            avg_order_value: orders.where(status: [:paid, :processing, :shipped, :delivered]).average(:total_amount)&.to_f || 0
          }
        end
        
        def order_list_json(order)
          {
            id: order.id,
            order_number: "##{order.id}",
            status: order.status,
            total_amount: order.total_amount,
            customer: {
              id: order.user.id,
              email: order.user.email,
              wallet_address: order.user.wallet_address
            },
            item_count: order.order_items.sum(:quantity),
            created_at: order.created_at,
            shipped_at: order.shipped_at,
            tracking_number: order.tracking_number
          }
        end
        
        def detailed_order_json(order)
          order_list_json(order).merge(
            shipping_address: order.shipping_address,
            carrier: order.carrier,
            estimated_delivery: order.estimated_delivery,
            delivered_at: order.delivered_at,
            blockchain_receipt_url: order.blockchain_receipt_url,
            notes: order.notes,
            items: order.order_items.map { |item|
              {
                id: item.id,
                merch_item: {
                  id: item.merch_item.id,
                  title: item.merch_item.title,
                  images: item.merch_item.images
                },
                quantity: item.quantity,
                price: item.price,
                total: item.quantity * item.price
              }
            }
          )
        end
        
        def generate_orders_csv(orders)
          require 'csv'
          
          CSV.generate(headers: true) do |csv|
            csv << ['Order ID', 'Date', 'Customer Email', 'Status', 'Total', 'Items', 'Tracking']
            
            orders.each do |order|
              csv << [
                order.id,
                order.created_at.strftime('%Y-%m-%d'),
                order.user.email,
                order.status,
                order.total_amount,
                order.order_items.sum(:quantity),
                order.tracking_number
              ]
            end
          end
        end
      end
    end
  end
end

