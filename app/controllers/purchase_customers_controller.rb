class PurchaseCustomersController < ApplicationController
  before_action :set_purchase_customer, only: [:show, :edit, :update, :destroy]
  
  def index
    @purchase_customers = PurchaseCustomer.active.order(:name)
    @purchase_customers = @purchase_customers.search_by_name(params[:search]) if params[:search].present?
  end
  
  def show
    @recent_invoices = @purchase_customer.purchase_invoices.recent.limit(10)
  end
  
  def new
    @purchase_customer = PurchaseCustomer.new
  end
  
  def create
    @purchase_customer = PurchaseCustomer.new(purchase_customer_params)
    
    if @purchase_customer.save
      redirect_to @purchase_customer, notice: 'Purchase customer was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @purchase_customer.update(purchase_customer_params)
      redirect_to @purchase_customer, notice: 'Purchase customer was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    if @purchase_customer.purchase_invoices.any?
      redirect_to purchase_customers_path, alert: 'Cannot delete customer with existing invoices.'
    else
      @purchase_customer.destroy
      redirect_to purchase_customers_path, notice: 'Purchase customer was successfully deleted.'
    end
  end
  
  def search
    @purchase_customers = PurchaseCustomer.active.search_by_name(params[:q]).limit(10)
    render json: @purchase_customers.map { |customer|
      {
        id: customer.id,
        name: customer.name,
        display_name: customer.display_name,
        address: customer.full_address,
        phone: customer.phone_number,
        email: customer.email,
        gst_number: customer.gst_number
      }
    }
  end
  
  private
  
  def set_purchase_customer
    @purchase_customer = PurchaseCustomer.find(params[:id])
  end
  
  def purchase_customer_params
    params.require(:purchase_customer).permit(
      :name, :address, :city, :state, :pincode, :phone_number,
      :email, :gst_number, :pan_number, :contact_person,
      :shipping_address, :is_active
    )
  end
end