# app/controllers/sales_products_controller.rb
class SalesProductsController < ApplicationController
  before_action :set_sales_product, only: [:show, :edit, :update, :destroy]
  
  def index
    @sales_products = SalesProduct.all
    
    # Apply filters
    @sales_products = @sales_products.by_category(params[:category]) if params[:category].present?
    @sales_products = @sales_products.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    # Apply stock filter
    case params[:stock_status]
    when 'in_stock'
      @sales_products = @sales_products.in_stock
    when 'low_stock'
      @sales_products = @sales_products.low_stock
    when 'out_of_stock'
      @sales_products = @sales_products.out_of_stock
    end
    
    @sales_products = @sales_products.order(:name)
    
    # Calculate summary data
    @total_stock_value = @sales_products.sum(&:stock_value)
    @low_stock_count = SalesProduct.low_stock.count
    @categories_count = SalesProduct.categories.count
  end
  
  def show
  end
  
  def new
    @sales_product = SalesProduct.new
  end
  
  def create
    @sales_product = SalesProduct.new(sales_product_params)
    
    respond_to do |format|
      if @sales_product.save
        format.html { redirect_to sales_products_path, notice: 'Sales product was successfully created.' }
        format.json { render json: { success: true, product: @sales_product, message: 'Product created successfully' } }
      else
        format.html { render :new }
        format.json { render json: { success: false, errors: @sales_product.errors.full_messages, message: 'Failed to create product' } }
      end
    end
  end
  
  def edit
  end
  
  def update
    if @sales_product.update(sales_product_params)
      redirect_to @sales_product, notice: 'Sales product was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @sales_product.destroy
    redirect_to sales_products_path, notice: 'Sales product was successfully deleted.'
  end
  
  def search
    @products = SalesProduct.where('name ILIKE ?', "%#{params[:term]}%").limit(10)
    render json: @products.map { |p| { 
      id: p.id, 
      name: p.name, 
      price: p.sales_price,
      stock: p.current_stock,
      unit: p.measuring_unit
    } }
  end
  
  private
  
  def set_sales_product
    @sales_product = SalesProduct.find(params[:id])
  end
  
  def sales_product_params
    params.require(:sales_product).permit(:name, :category, :purchase_price, :sales_price, 
                                         :measuring_unit, :opening_stock, :current_stock, 
                                         :enable_serialization, :description, :tax_rate, :hsn_sac)
  end
end