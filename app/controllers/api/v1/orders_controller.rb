module Api
  module V1
    class OrdersController < BaseController
      load_and_authorize_resource
      
      # GET /api/v1/orders
      def index
        @orders = current_user.orders.includes(:order_items).order(created_at: :desc)
        
        # Filter by status
        @orders = @orders.where(status: params[:status]) if params[:status]
        
        @paginated = paginate(@orders)
        
        render json: {
          orders: @paginated.map { |order| order_json(order) },
          meta: pagination_meta(@orders, @paginated)
        }
      end
      
      # GET /api/v1/orders/:id
      def show
        render json: {
          order: detailed_order_json(@order),
          items: @order.order_items.map { |item| order_item_json(item) }
        }
      end
      
      # POST /api/v1/orders
      def create
        items_data = params[:items] || []
        
        if items_data.empty?
          return render json: { error: 'Order must have at least one item' }, status: :bad_request
        end
        
        # Calculate total
        total = 0
        order_items = []
        
        items_data.each do |item_data|
          orderable = find_orderable(item_data[:orderable_type], item_data[:orderable_id])
          quantity = item_data[:quantity].to_i
          
          unless orderable
            return render json: { error: 'Invalid item' }, status: :bad_request
          end
          
          price = orderable.respond_to?(:price) ? orderable.price : 0
          total += price * quantity
          
          order_items << {
            orderable: orderable,
            quantity: quantity,
            price: price
          }
        end
        
        # Verify payment
        signature = params[:transaction_signature]
        unless signature
          return render json: { error: 'Payment signature required' }, status: :bad_request
        end
        
        # TODO: Verify Solana transaction
        
        # Create order
        @order = current_user.orders.build(
          status: :paid,
          total_amount: total,
          shipping_address: params[:shipping_address]
        )
        
        if @order.save
          # Create order items
          order_items.each do |item_data|
            @order.order_items.create!(
              orderable: item_data[:orderable],
              quantity: item_data[:quantity],
              price: item_data[:price]
            )
          end
          
          render json: {
            order: detailed_order_json(@order),
            message: 'Order created successfully'
          }, status: :created
        else
          render json: { errors: @order.errors }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/orders/:id/cancel
      def cancel
        if @order.status.in?(['shipped', 'delivered'])
          return render json: { error: 'Cannot cancel shipped or delivered order' }, status: :unprocessable_entity
        end
        
        @order.update!(status: :cancelled)
        
        # TODO: Refund payment
        
        render json: {
          order: order_json(@order),
          message: 'Order cancelled successfully'
        }
      end
      
      private
      
      def find_orderable(type, id)
        case type
        when 'MerchItem'
          MerchItem.find_by(id: id)
        when 'FanPass'
          FanPass.find_by(id: id)
        when 'Track'
          Track.find_by(id: id)
        when 'Album'
          Album.find_by(id: id)
        else
          nil
        end
      end
      
      def order_json(order)
        {
          id: order.id,
          status: order.status,
          total_amount: order.total_amount,
          items_count: order.order_items.count,
          tracking_number: order.tracking_number,
          created_at: order.created_at
        }
      end
      
      def detailed_order_json(order)
        order_json(order).merge(
          shipping_address: order.shipping_address,
          updated_at: order.updated_at
        )
      end
      
      def order_item_json(item)
        {
          id: item.id,
          orderable_type: item.orderable_type,
          orderable_id: item.orderable_id,
          quantity: item.quantity,
          price: item.price,
          total: item.quantity * item.price
        }
      end
    end
  end
end

