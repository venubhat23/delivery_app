module Api
  module V1
    class AuthenticationController < BaseController
      skip_before_action :authenticate_request, only: [:customer_login, :customer_signup, :regenerate_token]

      # POST /api/v1/customer_login
      def customer_login
        @customer = Customer.find_by(phone_number: params[:phone_number])
        
        if @customer&.authenticate(params[:password]) && @customer.is_active?
          token = JsonWebToken.encode(customer_id: @customer.id)
          render json: { 
            token: token, 
            customer: {
              id: @customer.id,
              name: @customer.name,
              address: @customer.address,
              phone_number: @customer.phone_number,
              email: @customer.email,
              preferred_language: @customer.preferred_language,
              delivery_time_preference: @customer.delivery_time_preference,
              notification_method: @customer.notification_method,
              latitude: @customer.latitude,
              longitude: @customer.longitude
            }
          }, status: :ok
        else
          render json: { error: 'Invalid credentials or account inactive' }, status: :unauthorized
        end
      end

      # POST /api/v1/customer_signup
      def customer_signup
        @customer = Customer.new(customer_params)
        
        if @customer.save
          token = JsonWebToken.encode(customer_id: @customer.id)
          render json: { 
            token: token, 
            customer: {
              id: @customer.id,
              name: @customer.name,
              address: @customer.address,
              phone_number: @customer.phone_number,
              email: @customer.email,
              preferred_language: @customer.preferred_language,
              delivery_time_preference: @customer.delivery_time_preference,
              notification_method: @customer.notification_method,
              latitude: @customer.latitude,
              longitude: @customer.longitude
            }
          }, status: :created
        else
          render json: { errors: @customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/regenerate_token
      def regenerate_token
        @customer = Customer.find_by(phone_number: params[:phone_number])
        
        if @customer&.authenticate(params[:password]) && @customer.is_active?
          token = JsonWebToken.encode(customer_id: @customer.id)
          render json: { 
            token: token, 
            customer: {
              id: @customer.id,
              name: @customer.name,
              address: @customer.address,
              phone_number: @customer.phone_number,
              email: @customer.email,
              preferred_language: @customer.preferred_language,
              delivery_time_preference: @customer.delivery_time_preference,
              notification_method: @customer.notification_method
            }
          }, status: :ok
        else
          render json: { error: 'Invalid credentials or account inactive' }, status: :unauthorized
        end
      end

      private

      def customer_params
        params.permit(:name, :email, :phone_number, :password, :password_confirmation, :address, 
                     :latitude, :longitude, :preferred_language, :delivery_time_preference, 
                     :notification_method, :address_type, :address_landmark, :alt_phone_number)
      end
    end
  end
end