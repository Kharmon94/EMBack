module Api
  module V1
    module Artist
      class InventoryController < BaseController
        before_action :require_artist_role
        
        # GET /api/v1/artist/inventory
        def index
          @merch_items = current_artist.merch_items.includes(:product_variants).order(title: :asc)
          
          # Filter by stock status
          case params[:stock_status]
          when 'low'
            @merch_items = @merch_items.select { |item| item.low_stock? }
          when 'out'
            @merch_items = @merch_items.where('inventory_count = 0')
          when 'in_stock'
            @merch_items = @merch_items.where('inventory_count > 0')
          end
          
          render json: {
            items: @merch_items.map { |item| inventory_json(item) },
            alerts: {
              low_stock_count: current_artist.merch_items.select { |item| item.low_stock? }.count,
              out_of_stock_count: current_artist.merch_items.where('inventory_count = 0').count
            }
          }
        end
        
        # PATCH /api/v1/artist/inventory/:id/adjust
        def adjust_stock
          @merch_item = current_artist.merch_items.find(params[:id])
          
          case params[:adjustment_type]
          when 'set'
            @merch_item.update!(inventory_count: params[:quantity])
          when 'add'
            @merch_item.increment!(:inventory_count, params[:quantity])
          when 'subtract'
            @merch_item.decrement!(:inventory_count, params[:quantity])
          end
          
          render json: {
            item: inventory_json(@merch_item),
            message: 'Inventory updated'
          }
        end
        
        # PATCH /api/v1/artist/inventory/:id/variant/:variant_id/adjust
        def adjust_variant_stock
          @variant = ProductVariant.joins(:merch_item)
                                   .where(merch_items: { artist_id: current_artist.id })
                                   .find(params[:variant_id])
          
          case params[:adjustment_type]
          when 'set'
            @variant.update!(inventory_count: params[:quantity])
          when 'add'
            @variant.increment!(:inventory_count, params[:quantity])
          when 'subtract'
            @variant.decrement!(:inventory_count, params[:quantity])
          end
          
          render json: {
            variant: variant_json(@variant),
            message: 'Variant inventory updated'
          }
        end
        
        private
        
        def require_artist_role
          unless current_user&.artist?
            render json: { error: 'Artist access required' }, status: :forbidden
          end
        end
        
        def inventory_json(item)
          {
            id: item.id,
            title: item.title,
            sku: item.sku,
            inventory_count: item.inventory_count,
            low_stock_threshold: item.low_stock_threshold,
            low_stock: item.low_stock?,
            in_stock: item.in_stock?,
            variants: item.product_variants.map { |v| variant_json(v) },
            images: item.images&.first
          }
        end
        
        def variant_json(variant)
          {
            id: variant.id,
            sku: variant.sku,
            variant_name: variant.variant_name,
            inventory_count: variant.inventory_count,
            low_stock_threshold: variant.low_stock_threshold,
            in_stock: variant.in_stock?,
            low_stock: variant.low_stock?
          }
        end
      end
    end
  end
end

