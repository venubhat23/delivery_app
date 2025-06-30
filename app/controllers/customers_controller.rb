# app/controllers/customers_controller.rb
class CustomersController < ApplicationController
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy]
  
  def index
    @customers = Customer.includes(:user).order(:name)
    @total_customers = @customers.count
  end
  
  def show
  end
  
  def new
    @customer = Customer.new
  end
  
  def create
    @customer = Customer.new(customer_params)
    @customer.user = current_user
    
    if @customer.save
      redirect_to @customer, notice: 'Customer was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: 'Customer was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @customer.destroy
    redirect_to customers_url, notice: 'Customer was successfully deleted.'
  end
  
  # Bulk import form
  def bulk_import
    @csv_template = Customer.csv_template
  end
  
  # Process bulk import
  def process_bulk_import
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      render json: { 
        success: false, 
        message: "Please paste CSV data" 
      }
      return
    end
    
    result = Customer.import_from_csv(csv_data, current_user)
    
    render json: result
  end
  
  # AJAX validation for CSV
  def validate_csv
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      render json: { valid: false, message: "Please paste CSV data" }
      return
    end
    
    begin
      require 'csv'
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      required_headers = [:name, :phone_number, :address]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        render json: { 
          valid: false, 
          message: "Missing required columns: #{missing_headers.join(', ')}" 
        }
      else
        render json: { 
          valid: true, 
          message: "CSV format is valid. Found #{csv.count} rows ready for import.",
          row_count: csv.count,
          headers: csv.headers
        }
      end
    rescue CSV::MalformedCSVError => e
      render json: { valid: false, message: "Invalid CSV format: #{e.message}" }
    rescue => e
      render json: { valid: false, message: "Error validating CSV: #{e.message}" }
    end
  end
  
  private
  
  def set_customer
    @customer = Customer.find(params[:id])
  end
  
  def customer_params
    params.require(:customer).permit(
      :name, :address, :shipping_address, :latitude, :longitude,
      :user_id, :delivery_person_id, :image_url,
      :phone_number, :email, :gst_number, :pan_number, :member_id
    )
  end
end