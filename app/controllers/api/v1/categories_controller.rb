module Api
  module V1
    class CategoriesController < BaseController
      skip_before_action :authenticate_api_user!, raise: false
      skip_authorization_check
      
      # GET /api/v1/categories
      def index
        @categories = ProductCategory.active.ordered.includes(:subcategories)
        
        # Only root categories or all based on param
        @categories = @categories.root_categories unless params[:include_all] == 'true'
        
        render json: {
          categories: @categories.map { |cat| category_json(cat) }
        }
      end
      
      # GET /api/v1/categories/:id
      def show
        @category = ProductCategory.active.find(params[:id])
        
        render json: {
          category: detailed_category_json(@category)
        }
      end
      
      private
      
      def category_json(category)
        {
          id: category.id,
          name: category.name,
          slug: category.slug,
          image_url: category.image_url,
          product_count: category.merch_items.count,
          subcategories: category.subcategories.active.map { |sub| category_json(sub) }
        }
      end
      
      def detailed_category_json(category)
        category_json(category).merge(
          description: category.description,
          full_path: category.full_path,
          parent: category.parent ? { id: category.parent.id, name: category.parent.name } : nil
        )
      end
    end
  end
end

