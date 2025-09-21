module Api
  module V1
    class ProductsController < BaseController
      before_action :set_product, only: [:show, :update, :destroy]
      
      # GET /api/v1/products
      def index
        products = Product.active.includes(:category)
        
        # Filter by category if provided
        products = products.by_category(params[:category_id]) if params[:category_id].present?
        
        # Filter available products only if requested
        products = products.available if params[:available] == 'true'
        
        # Filter subscription eligible products if requested
        products = products.subscription_eligible if params[:subscription_eligible] == 'true'
        
        # Search by name if provided
        products = products.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
        
        products = products.order(:name)
        
        render json: products, status: :ok
      end
      
      # GET /api/v1/products/:id
      def show
        render json: @product, status: :ok
      end
      
      # POST /api/v1/products
      def create
        @product = Product.new(product_params)
        
        if @product.save
          render json: @product, status: :created
        else
          render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT/PATCH /api/v1/products/:id
      def update
        if @product.update(product_params)
          render json: @product, status: :ok
        else
          render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/products/:id
      def destroy
        if @product.delivery_assignments.exists? || @product.invoice_items.exists?
          render json: { error: "Cannot delete product with existing orders or invoices" }, status: :unprocessable_entity
        else
          @product.destroy
          head :no_content
        end
      end
      
      # GET /api/v1/products/low_stock
      def low_stock
        products = Product.active.includes(:category)
                         .where('stock_alert_threshold IS NOT NULL AND available_quantity <= stock_alert_threshold')
                         .order(:available_quantity)
        
        render json: products, status: :ok
      end
      
      private
      
      def set_product
        @product = Product.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Product not found" }, status: :not_found
      end
      
      def product_params
        params.permit(:name, :description, :unit_type, :available_quantity, :price, 
                      :category_id, :image_url, :sku, :stock_alert_threshold, 
                      :is_subscription_eligible, :is_active, :is_gst_applicable,
                      :total_gst_percentage, :total_cgst_percentage, :total_sgst_percentage, :total_igst_percentage)
      end
      
      def ensure_admin
        unless current_user.admin?
          render json: { error: "Only administrators can manage products" }, status: :unauthorized
        end
      end
    end
  end
end