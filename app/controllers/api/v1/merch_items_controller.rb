module Api
  module V1
    class MerchItemsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:index, :show], raise: false
      load_and_authorize_resource except: [:index, :show]
      skip_authorization_check only: [:index, :show]
      before_action :set_merch_item, only: [:show, :update, :destroy]
      
      # GET /api/v1/merch
      def index
        @merch_items = MerchItem.includes(:artist, :product_category, :product_tags, :reviews)
        
        # Filter by artist
        @merch_items = @merch_items.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Filter by category
        if params[:category_id].present?
          category = ProductCategory.find(params[:category_id])
          category_ids = [category.id] + category.subcategories.pluck(:id)
          @merch_items = @merch_items.where(product_category_id: category_ids)
        end
        
        # Filter by tags
        @merch_items = @merch_items.joins(:product_tags).where(product_tags: { id: params[:tag_ids] }) if params[:tag_ids].present?
        
        # Filter by price range
        @merch_items = @merch_items.where('price >= ?', params[:min_price]) if params[:min_price].present?
        @merch_items = @merch_items.where('price <= ?', params[:max_price]) if params[:max_price].present?
        
        # Filter by rating
        @merch_items = @merch_items.where('rating_average >= ?', params[:min_rating]) if params[:min_rating].present?
        
        # Filter by availability
        @merch_items = @merch_items.in_stock if params[:in_stock] == 'true'
        
        # Filter featured
        @merch_items = @merch_items.featured if params[:featured] == 'true'
        
        # Filter token-gated
        @merch_items = @merch_items.token_gated if params[:token_gated] == 'true'
        
        # Search
        if params[:q].present?
          @merch_items = @merch_items.where(
            'title ILIKE ? OR description ILIKE ? OR brand ILIKE ?',
            "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%"
          )
        end
        
        # Sort
        @merch_items = case params[:sort]
                       when 'price_asc' then @merch_items.order(price: :asc)
                       when 'price_desc' then @merch_items.order(price: :desc)
                       when 'rating' then @merch_items.order(rating_average: :desc, rating_count: :desc)
                       when 'popular' then @merch_items.order(purchase_count: :desc)
                       when 'trending' then @merch_items.order(view_count: :desc)
                       when 'newest' then @merch_items.order(created_at: :desc)
                       else @merch_items.order(created_at: :desc)
                       end
        
        @paginated = paginate(@merch_items.distinct)
        
        render json: {
          merch_items: @paginated.map { |item| merch_json(item) },
          meta: pagination_meta(@merch_items, @paginated)
        }
      end
      
      # GET /api/v1/merch/:id
      def show
        # Track view if user is authenticated
        if current_user
          RecentlyViewedItem.track_view(current_user, @merch_item)
        end
        
        @merch_item.increment_view_count!
        
        render json: { 
          merch_item: detailed_merch_json(@merch_item),
          related_products: related_products_json
        }
      end
      
      # GET /api/v1/merch/:id/quick_view
      def quick_view
        render json: { merch_item: merch_json(@merch_item) }
      end
      
      # GET /api/v1/merch/recently_viewed
      def recently_viewed
        return render json: { items: [] } unless current_user
        
        items = current_user.recently_viewed_items
                             .includes(merch_item: :artist)
                             .recent
                             .limit(20)
        
        render json: {
          items: items.map { |rv| merch_json(rv.merch_item) }
        }
      end
      
      # POST /api/v1/merch
      def create
        @merch_item = current_artist.merch_items.build(merch_params)
        
        if @merch_item.save
          render json: {
            merch_item: detailed_merch_json(@merch_item),
            message: 'Merch item created successfully'
          }, status: :created
        else
          render json: { errors: @merch_item.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH /api/v1/merch/:id
      def update
        if @merch_item.update(merch_params)
          render json: { merch_item: detailed_merch_json(@merch_item) }
        else
          render json: { errors: @merch_item.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/merch/:id
      def destroy
        @merch_item.destroy
        render json: { message: 'Merch item deleted successfully' }
      end
      
      private
      
      def merch_params
        params.require(:merch_item).permit(
          :title, :description, :price, :inventory_count,
          :sku, :brand, :product_category_id, :featured,
          :low_stock_threshold, :weight,
          :token_gated, :minimum_tokens_required,
          :limited_edition, :edition_size, :edition_number,
          dimensions: {}, images: [], product_tag_ids: []
        )
      end
      
      def merch_json(item)
        {
          id: item.id,
          title: item.title,
          description: item.description,
          price: item.price,
          images: item.images,
          variants: item.variants,
          in_stock: item.in_stock?,
          inventory_count: item.inventory_count,
          rating_average: item.rating_average&.to_f || 0,
          rating_count: item.rating_count || 0,
          featured: item.featured,
          artist: {
            id: item.artist.id,
            name: item.artist.name,
            avatar_url: item.artist.avatar_url,
            verified: item.artist.verified
          }
        }
      end
      
      def detailed_merch_json(item)
        merch_json(item).merge(
          sku: item.sku,
          brand: item.brand,
          weight: item.weight,
          dimensions: item.dimensions,
          category: item.product_category ? { id: item.product_category.id, name: item.product_category.name } : nil,
          tags: item.product_tags.map { |tag| { id: tag.id, name: tag.name } },
          product_variants: item.product_variants.available.map { |v| variant_json(v) },
          token_gated: item.token_gated,
          minimum_tokens_required: item.minimum_tokens_required,
          limited_edition: item.limited_edition,
          edition_size: item.edition_size,
          edition_number: item.edition_number,
          low_stock: item.low_stock?,
          available_sizes: item.available_sizes,
          available_colors: item.available_colors,
          created_at: item.created_at,
          updated_at: item.updated_at
        )
      end
      
      def variant_json(variant)
        {
          id: variant.id,
          sku: variant.sku,
          size: variant.size,
          color: variant.color,
          material: variant.material,
          price: variant.final_price,
          inventory_count: variant.inventory_count,
          in_stock: variant.in_stock?,
          variant_name: variant.variant_name
        }
      end
      
      def related_products_json
        # Find related products by category or artist
        related = MerchItem.where.not(id: @merch_item.id)
        
        if @merch_item.product_category_id
          related = related.where(product_category_id: @merch_item.product_category_id)
        else
          related = related.where(artist_id: @merch_item.artist_id)
        end
        
        related.in_stock.limit(6).map { |item| merch_json(item) }
      end
      
      def set_merch_item
        @merch_item = MerchItem.find(params[:id])
      end
    end
  end
end

