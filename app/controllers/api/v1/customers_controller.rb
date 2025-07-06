class Api::V1::CustomersController < Api::V1::BaseController
  before_action :set_customer, only: [:show, :update, :destroy, :assign_delivery_person, :delivery_history]
  
  def index
    @customers = Customer.by_user(current_user)
    @customers = @customers.search(params[:search]) if params[:search].present?
    @customers = @customers.includes(:delivery_person, :user)
    
    render_paginated(@customers)
  end
  
  def show
    render json: {
      data: customer_with_details(@customer)
    }
  end
  
  def create
    @customer = current_user.customers.build(customer_params)
    
    if @customer.save
      render json: {
        message: 'Customer created successfully',
        data: customer_with_details(@customer)
      }, status: 201
    else
      render json: { errors: @customer.errors.full_messages }, status: 422
    end
  end
  
  def update
    if @customer.update(customer_params)
      render json: {
        message: 'Customer updated successfully',
        data: customer_with_details(@customer)
      }
    else
      render json: { errors: @customer.errors.full_messages }, status: 422
    end
  end
  
  def destroy
    @customer.destroy
    render json: { message: 'Customer deleted successfully' }
  end
  
  def bulk_import
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      return render json: { error: 'CSV data is required' }, status: 422
    end
    
    result = Customer.import_from_csv(csv_data, current_user)
    
    if result[:success]
      render json: {
        message: result[:message],
        data: {
          imported_count: result[:imported_count],
          total_processed: result[:total_processed],
          errors: result[:errors],
          skipped_rows: result[:skipped_rows]
        }
      }
    else
      render json: {
        error: result[:message],
        data: {
          errors: result[:errors],
          skipped_rows: result[:skipped_rows]
        }
      }, status: 422
    end
  end
  
  def validate_csv
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      return render json: { error: 'CSV data is required' }, status: 422
    end
    
    # Validate CSV structure without importing
    begin
      require 'csv'
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      required_headers = [:name, :phone_number, :address]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        return render json: {
          valid: false,
          errors: ["Missing required columns: #{missing_headers.join(', ')}"]
        }, status: 422
      end
      
      render json: {
        valid: true,
        headers: csv.headers,
        preview: csv.first(5).map(&:to_h),
        total_rows: csv.count
      }
    rescue CSV::MalformedCSVError => e
      render json: {
        valid: false,
        errors: ["Invalid CSV format: #{e.message}"]
      }, status: 422
    end
  end
  
  def export_csv
    @customers = Customer.by_user(current_user).includes(:delivery_person)
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Name', 'Phone', 'Address', 'Email', 'GST Number', 'PAN Number', 'Member ID', 'Latitude', 'Longitude', 'Delivery Person', 'Created At']
      
      @customers.each do |customer|
        csv << [
          customer.name,
          customer.phone_number,
          customer.address,
          customer.email,
          customer.gst_number,
          customer.pan_number,
          customer.member_id,
          customer.latitude,
          customer.longitude,
          customer.delivery_person_name,
          customer.created_at.strftime('%Y-%m-%d')
        ]
      end
    end
    
    render json: {
      csv_data: csv_data,
      filename: "customers_export_#{Date.current}.csv"
    }
  end
  
  def assign_delivery_person
    delivery_person = User.find_by(id: params[:delivery_person_id], role: 'delivery_person')
    
    if delivery_person.nil?
      return render json: { error: 'Invalid delivery person' }, status: 422
    end
    
    if @customer.update(delivery_person: delivery_person)
      render json: {
        message: 'Delivery person assigned successfully',
        data: customer_with_details(@customer)
      }
    else
      render json: { errors: @customer.errors.full_messages }, status: 422
    end
  end
  
  def delivery_history
    @deliveries = @customer.delivery_assignments.includes(:product, :user)
                           .order(scheduled_date: :desc)
                           .page(params[:page] || 1)
                           .per(params[:per_page] || 25)
    
    render json: {
      data: @deliveries.map { |delivery| delivery_assignment_details(delivery) },
      pagination: {
        current_page: @deliveries.current_page,
        per_page: @deliveries.limit_value,
        total_pages: @deliveries.total_pages,
        total_count: @deliveries.total_count
      }
    }
  end
  
  private
  
  def set_customer
    @customer = Customer.by_user(current_user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Customer not found' }, status: 404
  end
  
  def customer_params
    params.require(:customer).permit(
      :name, :phone_number, :address, :email, :gst_number, 
      :pan_number, :member_id, :latitude, :longitude, :image_url
    )
  end
  
  def customer_with_details(customer)
    {
      id: customer.id,
      name: customer.name,
      phone_number: customer.phone_number,
      address: customer.address,
      email: customer.email,
      gst_number: customer.gst_number,
      pan_number: customer.pan_number,
      member_id: customer.member_id,
      latitude: customer.latitude,
      longitude: customer.longitude,
      image_url: customer.image_url,
      has_coordinates: customer.has_coordinates?,
      coordinates_string: customer.coordinates_string,
      google_maps_url: customer.google_maps_url,
      delivery_person: customer.delivery_person&.slice(:id, :name, :phone),
      total_deliveries: customer.total_deliveries,
      pending_deliveries: customer.pending_deliveries,
      completed_deliveries: customer.completed_deliveries,
      total_invoice_amount: customer.total_invoice_amount,
      pending_invoice_amount: customer.pending_invoice_amount,
      created_at: customer.created_at,
      updated_at: customer.updated_at
    }
  end
  
  def delivery_assignment_details(assignment)
    {
      id: assignment.id,
      scheduled_date: assignment.scheduled_date,
      status: assignment.status,
      quantity: assignment.quantity,
      unit: assignment.unit,
      total_amount: assignment.total_amount,
      product: assignment.product&.slice(:id, :name, :price),
      delivery_person: assignment.user&.slice(:id, :name, :phone),
      completed_at: assignment.completed_at,
      created_at: assignment.created_at
    }
  end
end