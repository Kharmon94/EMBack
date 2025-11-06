module Api
  module V1
    class CartController < BaseController
      # POST /api/v1/cart/calculate_shipping
      def calculate_shipping
        cart_items = params[:cart_items] || []
        
        # Group items by seller (artist)
        items_by_seller = group_items_by_seller(cart_items)
        
        shipping_breakdown = items_by_seller.map do |artist_id, items|
          artist = ::Artist.find(artist_id)
          subtotal = calculate_subtotal(items)
          shipping_fee = calculate_shipping_fee(items)
          
          {
            artist_id: artist.id,
            artist_name: artist.name,
            items_count: items.sum { |i| i[:quantity] },
            subtotal: subtotal,
            shipping_fee: shipping_fee,
            total: subtotal + shipping_fee
          }
        end
        
        grand_total = shipping_breakdown.sum { |s| s[:total] }
        
        render json: {
          sellers: shipping_breakdown,
          grand_total: grand_total
        }
      end
      
      # POST /api/v1/cart/checkout
      def checkout
        cart_items = params[:cart_items] || []
        shipping_address = params[:shipping_address] || {}
        
        unless current_user
          render json: { error: 'Authentication required' }, status: :unauthorized
          return
        end
        
        # Group items by seller
        items_by_seller = group_items_by_seller(cart_items)
        
        # Create parent CartOrder
        cart_order = current_user.cart_orders.build(
          total_amount: 0,
          shipping_address: shipping_address,
          status: :pending,
          payment_status: :unpaid
        )
        
        sellers_payment_info = []
        total_amount = 0
        
        ActiveRecord::Base.transaction do
          # Create child order for each seller
          items_by_seller.each do |artist_id, items|
            artist = ::Artist.find(artist_id)
            subtotal = calculate_subtotal(items)
            shipping_fee = calculate_shipping_fee(items)
            seller_total = subtotal + shipping_fee
            
            # Create order for this seller
            order = current_user.orders.build(
              cart_order: cart_order,
              total_amount: subtotal,
              shipping_fee: shipping_fee,
              seller_amount: seller_total, # For now, seller gets 100%
              shipping_address: shipping_address,
              status: :pending
            )
            
            # Create order items
            items.each do |item|
              merch_item = ::MerchItem.find(item[:merch_item_id])
              variant = item[:variant_id] ? ::ProductVariant.find(item[:variant_id]) : nil
              price = variant ? variant.final_price : merch_item.price
              
              order.order_items.build(
                merch_item: merch_item,
                quantity: item[:quantity],
                price: price
              )
            end
            
            order.save!
            total_amount += seller_total
            
            sellers_payment_info << {
              artist_id: artist.id,
              artist_name: artist.name,
              wallet_address: artist.wallet_address,
              amount: seller_total.to_f,
              order_id: order.id
            }
          end
          
          cart_order.total_amount = total_amount
          cart_order.save!
        end
        
        render json: {
          cart_order_id: cart_order.id,
          total_amount: total_amount.to_f,
          sellers: sellers_payment_info,
          message: 'Orders created. Please complete payment.'
        }, status: :created
      end
      
      # POST /api/v1/cart/confirm_payment
      def confirm_payment
        cart_order_id = params[:cart_order_id]
        transaction_signature = params[:transaction_signature]
        
        cart_order = CartOrder.find(cart_order_id)
        
        unless cart_order.user_id == current_user&.id
          render json: { error: 'Unauthorized' }, status: :forbidden
          return
        end
        
        # TODO: Verify Solana transaction signature here
        # For now, we'll trust the frontend
        
        ActiveRecord::Base.transaction do
          cart_order.update!(
            status: :paid,
            payment_status: :confirmed,
            transaction_signature: transaction_signature,
            blockchain_receipt_url: "https://solscan.io/tx/#{transaction_signature}"
          )
          
          # Mark all child orders as paid
          cart_order.orders.each do |order|
            order.update!(status: :paid)
            
            # Decrement inventory
            order.order_items.each do |item|
              if item.merch_item.inventory_count
                item.merch_item.decrement!(:inventory_count, item.quantity)
              end
              item.merch_item.increment_purchase_count!
            end
            
            # Auto-create conversation with seller
            seller_user = order.order_items.first&.merch_item&.artist&.user
            if seller_user && seller_user.id != current_user.id
              existing = Conversation.between_users(current_user.id, seller_user.id)
              
              unless existing
                conversation = Conversation.create!(
                  subject: "Order ##{order.id}",
                  order_id: order.id
                )
                
                conversation.conversation_participants.create!(user: current_user)
                conversation.conversation_participants.create!(user: seller_user)
                
                # Send system message
                conversation.direct_messages.create!(
                  user: current_user,
                  content: "Order ##{order.id} has been confirmed. Thank you for your purchase!",
                  system_message: true
                )
              end
            end
          end
        end
        
        render json: {
          cart_order: {
            id: cart_order.id,
            status: cart_order.status,
            total_amount: cart_order.total_amount,
            transaction_signature: cart_order.transaction_signature
          },
          message: 'Payment confirmed successfully'
        }
      end
      
      private
      
      def group_items_by_seller(cart_items)
        items_by_seller = {}
        
        cart_items.each do |item|
          merch_item = ::MerchItem.find(item[:merch_item_id] || item['merch_item_id'])
          artist_id = merch_item.artist_id
          
          items_by_seller[artist_id] ||= []
          items_by_seller[artist_id] << {
            merch_item_id: merch_item.id,
            variant_id: item[:variant_id] || item['variant_id'],
            quantity: (item[:quantity] || item['quantity']).to_i
          }
        end
        
        items_by_seller
      end
      
      def calculate_subtotal(items)
        subtotal = 0
        items.each do |item|
          merch_item = ::MerchItem.find(item[:merch_item_id])
          variant = item[:variant_id] ? ::ProductVariant.find(item[:variant_id]) : nil
          price = variant ? variant.final_price : merch_item.price
          subtotal += price * item[:quantity]
        end
        subtotal
      end
      
      def calculate_shipping_fee(items)
        # Simple flat rate per seller for now
        # Could be enhanced with weight-based calculation using merch_item.weight
        base_rate = 5.00
        item_count = items.sum { |i| i[:quantity] }
        
        # $5 base + $1 per additional item
        base_rate + ((item_count - 1) * 1.00)
      end
    end
  end
end

