module Api
  module V1
    class CustomerAddressesController < BaseController
      before_action :set_customer, only: [:show, :update, :destroy]
      
      # POST /api/v1/customer_address
      def create
        # For create, we need customer_id to find the customer
        if params[:customer_id].blank?
          return render json: { errors: ["Customer ID is required"] }, status: :unprocessable_entity
        end
        
        @customer = Customer.find_by(id: params[:customer_id])
        unless @customer
          return render json: { errors: ["Customer not found"] }, status: :not_found
        end
        
        # Set address API context for validations
        @customer.address_api_context = true
        
        # Process parameters to handle existing field mapping
        processed_params = process_address_params(customer_address_params)
        
        if @customer.update(processed_params)
          render json: @customer.as_json(address_api_format: true), status: :created
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/customer_address/:id
      def show
        render json: @customer.as_json, status: :ok
      end
      
      # PUT/PATCH /api/v1/customer_address/:id
      def update
        # Set address API context for validations
        
        # Process parameters to handle existing field mapping
        processed_params = process_address_params(customer_address_params)
        if @customer.update(processed_params)
          render json: @customer.as_json(address_api_format: true), status: :ok
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/customer_address/:id (optional, clears address fields)
      def destroy
        address_fields = {
          address_line: nil,
          address: nil, # Clear existing address field too
          city: nil,
          state: nil,
          postal_code: nil,
          country: nil,
          address_landmark: nil, # Clear existing landmark field
          full_address: nil,
          longitude: nil,
          latitude: nil
        }
        
        if @customer.update(address_fields)
          render json: { message: "Customer address cleared successfully" }, status: :ok
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/customer_addresses (optional, to get addresses for customers)
      def index
        if params[:customer_id].present?
          @customer = Customer.find_by(id: params[:customer_id])
          if @customer
            render json: [@customer.as_json(address_api_format: true)], status: :ok
          else
            render json: { error: "Customer not found" }, status: :not_found
          end
        else
          # Return all customers with address information
          @customers = Customer.active
          addresses = @customers.map { |customer| customer.as_json(address_api_format: true) }
          render json: addresses, status: :ok
        end
      end
 
      private
      
      def set_customer
        @customer = Customer.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Customer not found" }, status: :not_found
      end
      
      def customer_address_params
        params.permit( :city, :state, :postal_code, 
                      :country, :phone_number, :landmark, :full_address, 
                      :longitude, :latitude)
      end
      
      def process_address_params(params)
        processed = params.dup
        
        # Map address_line to both address_line (new field) and address (existing field)

        
        # Map landmark to address_landmark (existing field)
        if params[:landmark].present?
          processed[:address_landmark] = params[:landmark]
          processed.delete(:landmark) # Remove landmark since we're using address_landmark
        end
        
        if params[:full_address].present?
          processed[:address] = params[:full_address]
          processed.delete(:full_address) # Remove landmark since we're using address_landmark
        end
        processed
      end
    end
  end
end