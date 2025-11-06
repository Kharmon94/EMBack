module Api
  module V1
    class ProductVariantsController < BaseController
      before_action :set_merch_item, only: [:create]
      before_action :set_variant, only: [:update, :destroy]
      load_and_authorize_resource :merch_item, only: [:create]
      load_and_authorize_resource :product_variant, only: [:update, :destroy]
      
      # POST /api/v1/merch/:merch_item_id/variants
      def create
        @variant = @merch_item.product_variants.build(variant_params)
        
        if @variant.save
          render json: {
            variant: variant_json(@variant),
            message: 'Variant created successfully'
          }, status: :created
        else
          render json: { errors: @variant.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/variants/:id
      def update
        if @variant.update(variant_params)
          render json: { variant: variant_json(@variant) }
        else
          render json: { errors: @variant.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/variants/:id
      def destroy
        @variant.destroy
        render json: { message: 'Variant deleted successfully' }
      end
      
      private
      
      def set_merch_item
        @merch_item = MerchItem.find(params[:merch_item_id])
        
        # Ensure current user owns this merch item
        unless current_user&.artist_id == @merch_item.artist_id || current_user&.admin?
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end
      
      def set_variant
        @variant = ProductVariant.find(params[:id])
        @merch_item = @variant.merch_item
        
        # Ensure current user owns this merch item
        unless current_user&.artist_id == @merch_item.artist_id || current_user&.admin?
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end
      
      def variant_params
        params.require(:product_variant).permit(
          :sku, :size, :color, :material, :price_modifier,
          :inventory_count, :low_stock_threshold, :available
        )
      end
      
      def variant_json(variant)
        {
          id: variant.id,
          merch_item_id: variant.merch_item_id,
          sku: variant.sku,
          size: variant.size,
          color: variant.color,
          material: variant.material,
          price_modifier: variant.price_modifier,
          final_price: variant.final_price,
          inventory_count: variant.inventory_count,
          low_stock_threshold: variant.low_stock_threshold,
          available: variant.available,
          in_stock: variant.in_stock?,
          variant_name: variant.variant_name
        }
      end
    end
  end
end

