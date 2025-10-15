module Api
  module V1
    class CustomersController < BaseController
      before_action :set_customer, only: [:show, :update_settings]
      
      # POST /api/v1/customers/:id/update_location
      def update_location
        customer = Customer.find(params[:id])
        
        # Only delivery person or admin can update customer location
        unless current_user.delivery_person? || current_user.admin?
          return render json: { error: "Unauthorized to update customer location" }, status: :unauthorized
        end
        
        if customer.update(customer_location_params)
          render json: {
            message: "Customer address and location updated successfully.",
            customer: {
              id: customer.id,
              name: customer.name,
              updated_address: customer.address,
              lat: customer.latitude,
              lng: customer.longitude,
              image_url: customer.image_url
            }
          }, status: :ok
        else
          render json: { errors: customer.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/customers
      def create
        @customer = Customer.new(customer_params)

        if @customer.save
          # Send WhatsApp notification to owner about new customer signup
          begin
            whatsapp_service = TwilioWhatsappService.new
            whatsapp_service.send_customer_signup_notification(@customer)
          rescue => e
            Rails.logger.error "Failed to send WhatsApp notification for customer signup: #{e.message}"
          end

          render json: @customer, status: :created
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/customers
      def index
        # For delivery persons, only show customers assigned to them via delivery assignments
        if current_user.delivery_person?
          customer_ids = DeliveryAssignment.where(user_id: current_user.id).distinct.pluck(:customer_id)
          customers = Customer.active.where(id: customer_ids).includes(:user, :delivery_person)
        else
          customers = Customer.active.includes(:user, :delivery_person)
          # Filter by delivery person if provided
          customers = customers.by_delivery_person(params[:delivery_person_id]) if params[:delivery_person_id].present?
        end
        
        # Search by name if provided
        customers = customers.joins(:user).where("users.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
        
        customers = customers.order('users.name')
        
        render json: customers, status: :ok
      end

      # GET /api/v1/customers/:id
      def show
        render json: @customer, status: :ok
      end
      
      # PUT /api/v1/customers/:id/settings
      def update_settings
        # Parse delivery preferences from JSON if provided
        delivery_preferences = parse_delivery_preferences(params[:delivery_preferences])
        
        customer_settings = customer_settings_params
        customer_settings[:delivery_preferences] = delivery_preferences if delivery_preferences
        
        if @customer.update(customer_settings)
          render json: {
            message: "Settings updated successfully",
            customer: @customer.as_json(include: {
              user: { only: [:id, :name, :email, :phone] }
            })
          }, status: :ok
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end
 
      private
      
      def set_customer
        @customer = Customer.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Customer not found" }, status: :not_found
      end
      
      def customer_location_params
        params.permit(:new_address, :lat, :lng, :image_url).transform_keys do |key| 
          case key
          when 'new_address' then 'address'
          when 'lat' then 'latitude'
          when 'lng' then 'longitude'
          else key
          end
        end
      end
      
      def customer_params
        params.permit(:name, :address, :latitude, :longitude, :user_id, :image_url,
                      :phone_number, :email, :gst_number, :pan_number, :member_id,
                      :shipping_address, :preferred_language, :delivery_time_preference,
                      :notification_method, :alt_phone_number, :profile_image_url,
                      :address_landmark, :address_type, :is_active)
      end
      
      def customer_settings_params
        params.permit(:phone_number, :email, :preferred_language, :delivery_time_preference,
                      :notification_method, :alt_phone_number, :address_landmark, 
                      :address_type, :shipping_address)
      end
      
      def parse_delivery_preferences(preferences_param)
        return nil unless preferences_param.present?
        
        if preferences_param.is_a?(String)
          JSON.parse(preferences_param)
        elsif preferences_param.is_a?(Hash)
          preferences_param
        else
          nil
        end
      rescue JSON::ParserError
        nil
      end
    end
  end
end
