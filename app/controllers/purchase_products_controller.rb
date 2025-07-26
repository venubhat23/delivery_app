class PurchaseProductsController < ApplicationController
  before_action :set_purchase_product, only: [:show, :edit, :update, :destroy, :mark_as_paid]
  
  def index
    @purchase_products = PurchaseProduct.all
    @purchase_products = @purchase_products.by_category(params[:category]) if params[:category].present?
    @purchase_products = @purchase_products.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @purchase_products = @purchase_products
    
    @categories = PurchaseProduct.categories

  @purchase_products = PurchaseProduct.all
  @total_purchase_value = @purchase_products.sum { |p| p.purchase_price.to_f * p.current_stock.to_i }
  @total_sales_value = @purchase_products.sum { |p| p.sales_price.to_f * p.current_stock.to_i }
  @low_stock_count = @purchase_products.where('current_stock <= ?', 10).count
  @categories_count = @purchase_products.distinct.count(:category)

  end
  
  def show
  end
  
  def mark_as_paid
    @purchase_product.update(status: "paid")
    redirect_to purchase_products_path, notice: "Product marked as paid!"
  end

  def new
    @purchase_product = PurchaseProduct.new
  end
  
  def create
    @purchase_product = PurchaseProduct.new(purchase_product_params)
    
    if @purchase_product.save
      respond_to do |format|
        format.html { redirect_to purchase_products_path, notice: 'Purchase product was successfully created.' }
        format.json { 
          render json: { 
            success: true, 
            product: {
              id: @purchase_product.id,
              name: @purchase_product.name,
              display_name: @purchase_product.display_name,
              purchase_price: @purchase_product.purchase_price,
              sales_price: @purchase_product.sales_price,
              hsn_sac: @purchase_product.hsn_sac,
              measuring_unit: @purchase_product.measuring_unit
            }
          }
        }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.json { 
          render json: { 
            success: false, 
            errors: @purchase_product.errors.full_messages 
          }
        }
      end
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
    render json: @products.map { |p| { 
      id: p.id, 
      name: p.name, 
      price: p.purchase_price,
      hsn_sac: p.hsn_sac,
      measuring_unit: p.measuring_unit
    } }
  end
  
  private
  
  def set_purchase_product
    @purchase_product = PurchaseProduct.find(params[:id])
  end
  
  def purchase_product_params
    params.require(:purchase_product).permit(:name, :category, :purchase_price, :sales_price, 
                                           :measuring_unit, :opening_stock, :current_stock, 
                                           :enable_serialization, :description, :hsn_sac)
  end
end
