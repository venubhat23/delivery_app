class CustomerAddressesController < ApplicationController
  before_action :set_customer_address, only: [:show, :edit, :update, :destroy, :set_default]
  before_action :set_customer, only: [:index, :new, :create]
  before_action :authenticate_user!

  def index
    if @customer
      @customer_addresses = @customer.customer_addresses.order(:is_default => :desc, :created_at => :desc)
    else
      @customer_addresses = CustomerAddress.includes(:customer)
      @customer_addresses = @customer_addresses.by_type(params[:address_type]) if params[:address_type].present?
      @customer_addresses = @customer_addresses.page(params[:page])
    end
  end

  def show
  end

  def new
    @customer_address = (@customer || Customer.new).customer_addresses.build
    @customers = Customer.active.order(:name) unless @customer
  end

  def edit
  end

  def create
    @customer_address = CustomerAddress.new(customer_address_params)

    if @customer_address.save
      if @customer
        redirect_to customer_customer_addresses_path(@customer), notice: 'Address was successfully created.'
      else
        redirect_to customer_addresses_path, notice: 'Address was successfully created.'
      end
    else
      @customers = Customer.active.order(:name) unless @customer
      render :new
    end
  end

  def update
    if @customer_address.update(customer_address_params)
      redirect_to customer_addresses_path, notice: 'Address was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    customer = @customer_address.customer
    @customer_address.destroy
    
    if params[:customer_id]
      redirect_to customer_customer_addresses_path(customer), notice: 'Address was successfully deleted.'
    else
      redirect_to customer_addresses_path, notice: 'Address was successfully deleted.'
    end
  end

  def set_default
    @customer_address.set_as_default!
    redirect_back(fallback_location: customer_addresses_path, notice: 'Default address updated.')
  end

  def bulk_import
    if params[:addresses_data].present?
      result = CustomerAddress.bulk_import_addresses(params[:addresses_data])
      render json: result
    else
      render json: { error: 'No address data provided' }, status: :bad_request
    end
  end

  private

  def set_customer_address
    @customer_address = CustomerAddress.find(params[:id])
  end

  def set_customer
    @customer = Customer.find(params[:customer_id]) if params[:customer_id]
  end

  def customer_address_params
    params.require(:customer_address).permit(
      :customer_id, :address_type, :street_address, :city, :state, 
      :pincode, :landmark, :is_default
    )
  end
end