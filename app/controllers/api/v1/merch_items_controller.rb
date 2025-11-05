module Api
  module V1
    class MerchItemsController < BaseController
      skip_before_action :authenticate_user!, only: [:index, :show]
      load_and_authorize_resource except: [:index, :show]
      skip_authorization_check only: [:index, :show]
      before_action :set_merch_item, only: [:show, :update, :destroy]
      
      # GET /api/v1/merch
      def index
        @merch_items = MerchItem.includes(:artist)
        
        # Filter by artist
        @merch_items = @merch_items.where(artist_id: params[:artist_id]) if params[:artist_id]
        
        # Filter by availability
        @merch_items = @merch_items.where('inventory_count > 0') if params[:in_stock] == 'true'
        
        # Search
        @merch_items = @merch_items.where('title ILIKE ?', "%#{params[:q]}%") if params[:q].present?
        
        @merch_items = @merch_items.order(created_at: :desc)
        @paginated = paginate(@merch_items)
        
        render json: {
          merch_items: @paginated.map { |item| merch_json(item) },
          meta: pagination_meta(@merch_items, @paginated)
        }
      end
      
      # GET /api/v1/merch/:id
      def show
        render json: { merch_item: detailed_merch_json(@merch_item) }
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
          variants: {}, images: []
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
          in_stock: item.inventory_count > 0,
          inventory_count: item.inventory_count,
          artist: {
            id: item.artist.id,
            name: item.artist.name,
            avatar_url: item.artist.avatar_url
          }
        }
      end
      
      def detailed_merch_json(item)
        merch_json(item).merge(
          created_at: item.created_at,
          updated_at: item.updated_at
        )
      end
      
      def set_merch_item
        @merch_item = MerchItem.find(params[:id])
      end
    end
  end
end

