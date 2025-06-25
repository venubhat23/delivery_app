class PurchaseProductsController < ApplicationController
  before_action :set_purchase_product, only: [:show, :edit, :update, :destroy]
  
  def index
    @purchase_products = PurchaseProduct.all
    @purchase_products = @purchase_products.by_category(params[:category]) if params[:category].present?
    @purchase_products = @purchase_products.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @purchase_products = @purchase_products
    
    @categories = PurchaseProduct.categories
  end
  
  def show
  end
  
  def new
    @purchase_product = PurchaseProduct.new
  end
  
  def create
    @purchase_product = PurchaseProduct.new(purchase_product_params)
    
    if @purchase_product.save
      redirect_to purchase_products_path, notice: 'Purchase product was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @purchase_product.update(purchase_product_params)
      redirect_to @purchase_product, notice: 'Purchase product was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @purchase_product.destroy
    redirect_to purchase_products_path, notice: 'Purchase product was successfully deleted.'
  end
  
  def search
    @products = PurchaseProduct.where('name ILIKE ?', "%#{params[:term]}%").limit(10)
    render json: @products.map { |p| { id: p.id, name: p.name, price: p.sales_price } }
  end
  
  private
  
  def set_purchase_product
    @purchase_product = PurchaseProduct.find(params[:id])
  end
  
  def purchase_product_params
    params.require(:purchase_product).permit(:name, :category, :purchase_price, :sales_price, 
                                           :measuring_unit, :opening_stock, :current_stock, 
                                           :enable_serialization, :description)
  end
end
