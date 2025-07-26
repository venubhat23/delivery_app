class SalesCustomersController < ApplicationController
  before_action :set_sales_customer, only: [:show, :edit, :update, :destroy]
  
  def index
    @sales_customers = SalesCustomer.active.order(:name)
    @sales_customers = @sales_customers.search_by_name(params[:search]) if params[:search].present?
  end
  
  def show
  end
  
  def new
    @sales_customer = SalesCustomer.new
    if request.xhr?
      render partial: 'modal_form', locals: { sales_customer: @sales_customer }
    end
  end
  
  def create
    @sales_customer = SalesCustomer.new(sales_customer_params)
    @sales_customer.is_active = true if @sales_customer.is_active.nil?
    
    if @sales_customer.save
      if request.xhr?
        render json: {
          success: true,
          customer: {
            id: @sales_customer.id,
            name: @sales_customer.name,
            address: @sales_customer.full_address,
            phone: @sales_customer.phone_number,
            email: @sales_customer.email,
            gst_number: @sales_customer.gst_number,
            type: 'SalesCustomer'
          },
          message: 'Sales customer was successfully created.'
        }
      else
        redirect_to @sales_customer, notice: 'Sales customer was successfully created.'
      end
    else
      if request.xhr?
        render json: {
          success: false,
          errors: @sales_customer.errors.full_messages
        }, status: :unprocessable_entity
      else
        # For non-AJAX requests, render the modal form partial
        render partial: 'modal_form', locals: { sales_customer: @sales_customer }, status: :unprocessable_entity
      end
    end
  end
  
  def edit
  end
  
  def update
    if @sales_customer.update(sales_customer_params)
      redirect_to @sales_customer, notice: 'Sales customer was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @sales_customer.destroy
    redirect_to sales_customers_path, notice: 'Sales customer was successfully deleted.'
  end
  
  private
  
  def set_sales_customer
    @sales_customer = SalesCustomer.find(params[:id])
  end
  
  def sales_customer_params
    params.require(:sales_customer).permit(:name, :address, :city, :state, :pincode, 
                                           :phone_number, :email, :gst_number, :pan_number, 
                                           :contact_person, :shipping_address, :is_active)
  end
end