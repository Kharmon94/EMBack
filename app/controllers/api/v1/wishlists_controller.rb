module Api
  module V1
    class WishlistsController < BaseController
      load_and_authorize_resource
      
      # GET /api/v1/wishlists
      def index
        @wishlists = current_user.wishlists.includes(:wishlist_items)
        
        render json: {
          wishlists: @wishlists.map { |w| wishlist_json(w) }
        }
      end
      
      # GET /api/v1/wishlists/:id
      def show
        render json: { wishlist: detailed_wishlist_json(@wishlist) }
      end
      
      # POST /api/v1/wishlists
      def create
        @wishlist = current_user.wishlists.build(wishlist_params)
        
        if @wishlist.save
          render json: { wishlist: wishlist_json(@wishlist) }, status: :created
        else
          render json: { errors: @wishlist.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/wishlists/:id
      def update
        if @wishlist.update(wishlist_params)
          render json: { wishlist: wishlist_json(@wishlist) }
        else
          render json: { errors: @wishlist.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/wishlists/:id
      def destroy
        @wishlist.destroy
        render json: { message: 'Wishlist deleted successfully' }
      end
      
      # POST /api/v1/wishlists/:id/items
      def add_item
        item = @wishlist.wishlist_items.find_or_initialize_by(
          merch_item_id: params[:merch_item_id],
          product_variant_id: params[:product_variant_id]
        )
        item.notes = params[:notes] if params[:notes]
        
        if item.save
          render json: { 
            message: 'Item added to wishlist',
            wishlist: detailed_wishlist_json(@wishlist.reload)
          }
        else
          render json: { errors: item.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/wishlists/:id/items/:item_id
      def remove_item
        item = @wishlist.wishlist_items.find(params[:item_id])
        item.destroy
        
        render json: { 
          message: 'Item removed from wishlist',
          wishlist: detailed_wishlist_json(@wishlist.reload)
        }
      end
      
      private
      
      def wishlist_params
        params.require(:wishlist).permit(:name, :description, :public)
      end
      
      def wishlist_json(wishlist)
        {
          id: wishlist.id,
          name: wishlist.name,
          item_count: wishlist.wishlist_items.count,
          public: wishlist.public,
          created_at: wishlist.created_at
        }
      end
      
      def detailed_wishlist_json(wishlist)
        wishlist_json(wishlist).merge(
          description: wishlist.description,
          share_token: wishlist.share_token,
          items: wishlist.wishlist_items.includes(:merch_item, :product_variant).map { |item|
            {
              id: item.id,
              merch_item: basic_merch_json(item.merch_item),
              variant: item.product_variant ? variant_json(item.product_variant) : nil,
              notes: item.notes,
              added_at: item.created_at
            }
          }
        )
      end
      
      def basic_merch_json(merch)
        {
          id: merch.id,
          title: merch.title,
          price: merch.price,
          images: merch.images,
          in_stock: merch.in_stock?
        }
      end
      
      def variant_json(variant)
        {
          id: variant.id,
          sku: variant.sku,
          size: variant.size,
          color: variant.color,
          price: variant.final_price
        }
      end
    end
  end
end

