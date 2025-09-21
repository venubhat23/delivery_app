module Api
  module V1
    class CategoriesController < BaseController
      before_action :set_category, only: [:show, :update, :destroy]
      
      # GET /api/v1/categories
      def index
        categories = Category.order(:name)
        render json: categories, status: :ok
      end
      
      # GET /api/v1/categories/:id
      def show
        render json: @category, status: :ok
      end
      
      # POST /api/v1/categories
      def create
        @category = Category.new(category_params)
        
        if @category.save
          render json: @category, status: :created
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT/PATCH /api/v1/categories/:id
      def update
        if @category.update(category_params)
          render json: @category, status: :ok
        else
          render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/categories/:id
      def destroy
        if @category.products.exists?
          render json: { error: "Cannot delete category with associated products" }, status: :unprocessable_entity
        else
          @category.destroy
          head :no_content
        end
      end
      
      private
      
      def set_category
        @category = Category.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Category not found" }, status: :not_found
      end
      
      def category_params
        params.permit(:name, :description, :color, :is_active)
      end
    end
  end
end