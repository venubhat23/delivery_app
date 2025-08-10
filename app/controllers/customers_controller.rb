# app/controllers/customers_controller.rb
class CustomersController < ApplicationController
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy]
  
  def index
    # Optimize queries with proper includes to prevent N+1 queries
    @customers = Customer.includes(:user, :delivery_person, :delivery_assignments, :invoices)
    
    # Filter by delivery person if selected
    if params[:delivery_person_id].present? && params[:delivery_person_id] != 'all'
      @customers = @customers.where(delivery_person_id: params[:delivery_person_id])
      @selected_delivery_person_id = params[:delivery_person_id]
    else
      @selected_delivery_person_id = 'all'
    end
    
    # Search by term across multiple fields
    if params[:search].present?
      term = params[:search].strip
      # If exact member_id match exists, redirect to that customer
      exact_customer = Customer.find_by(member_id: term)
      exact_customer ||= Customer.find_by(phone_number: term)
      exact_customer ||= Customer.find_by(email: term)
      if exact_customer
        redirect_to exact_customer and return
      end
      @customers = @customers.search(term)
    end
    
    @customers = @customers.order(:name)
    @total_customers = @customers.count
    
    # Add pagination - 50 customers per page
    @customers = @customers.page(params[:page]).per(50)
    
    # Get all delivery people for the dropdown
    @delivery_people = User.delivery_people.order(:name)
  end
  
  def show
  end
  
  def new
    @customer = Customer.new
  end
  
  def create
    @customer = Customer.new(customer_params)
    @customer.user = current_user
    
    # Handle empty member_id by setting it to nil to avoid unique constraint violation
    @customer.member_id = nil if @customer.member_id.blank?
    
    @customer.password = "customer@123"
    @customer.password_confirmation = "customer@123"
    
    respond_to do |format|
      if @customer.save
        format.html { redirect_to @customer, notice: 'Customer was successfully created.' }
        format.json { render json: { success: true, customer: @customer, message: 'Customer created successfully' } }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @customer.errors.full_messages, message: 'Failed to create customer' } }
      end
    end
  end
  
  def edit
  end
  
  def update
    # Handle empty member_id by setting it to nil to avoid unique constraint violation
    params_to_update = customer_params
    params_to_update[:member_id] = nil if params_to_update[:member_id].blank?
    
    if @customer.update(params_to_update)
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
  
  # Download CSV template
  def download_template
    template_content = Customer.csv_template
    
    respond_to do |format|
      format.csv do
        send_data template_content,
                  filename: 'customers_template.csv',
                  type: 'text/csv',
                  disposition: 'attachment'
      end
    end
  end
  
  # Enhanced bulk import form
  def enhanced_bulk_import
    @csv_template = Customer.enhanced_csv_template
    @delivery_people = User.delivery_people.order(:name)
    @products = Product.order(:name)
  end
  
  # Process enhanced bulk import
  def process_enhanced_bulk_import
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      render json: { 
        success: false, 
        message: "Please paste CSV data" 
      }
      return
    end
    
    result = Customer.enhanced_bulk_import(csv_data, current_user)
    
    render json: result
  end
  
  # AJAX validation for enhanced CSV
  def validate_enhanced_csv
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      render json: { valid: false, message: "Please paste CSV data" }
      return
    end
    
    begin
      require 'csv'
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      required_headers = [:name, :phone_number, :address, :email, :gst_number, :pan_number, :delivery_person_id, :product_id, :quantity, :start_date, :end_date]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        render json: { 
          valid: false, 
          message: "Missing required columns: #{missing_headers.join(', ')}" 
        }
      elsif csv.count > 50
        render json: { 
          valid: false, 
          message: "Maximum 50 customers allowed per bulk import. Your file contains #{csv.count} rows." 
        }
      else
        render json: { 
          valid: true, 
          message: "CSV format is valid. Found #{csv.count} rows ready for enhanced import with delivery assignments.",
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
  
  # Download enhanced CSV template
  def download_enhanced_template
    template_content = Customer.enhanced_csv_template
    
    respond_to do |format|
      format.csv do
        send_data template_content,
                  filename: 'customers_enhanced_template.csv',
                  type: 'text/csv',
                  disposition: 'attachment'
      end
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