class ProductsController < ApplicationController
  before_action :require_login
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  def index
    @products = Product.includes(:category).all.order(:name)
    @products = @products.by_category(params[:category]) if params[:category].present?
    @total_products = @products.count
    @categories = Category.all.order(:name)
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    
    if @product.save
      redirect_to @product, notice: 'Product was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: 'Product was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_url, notice: 'Product was successfully deleted.'
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :unit_type, :available_quantity, :price,
      :is_gst_applicable, :total_gst_percentage, :total_cgst_percentage,
      :total_sgst_percentage, :total_igst_percentage, :category_id
    )
  end
end