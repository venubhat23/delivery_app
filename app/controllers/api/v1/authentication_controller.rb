module Api
  module V1
    class AuthenticationController < BaseController
      skip_before_action :authenticate_request, only: [:login, :signup, :customer_login, :refresh_token, :customer_signup]

      # POST /api/v1/login
      def login
        if params[:role] == 'customer'
          customer_login
        else
          # For admin and delivery_person
          @user = User.find_by(phone: params[:phone])

          if @user&.authenticate(params[:password]) && %w[admin delivery_person].include?(@user.role)
            token = JsonWebToken.encode(user_id: @user.id)
            refresh_token, refresh_record = issue_refresh_token(@user)
            render json: {
              token: token,
              refresh_token: refresh_token,
              token_expires_in: 24.hours.to_i,
              refresh_token_expires_in: (refresh_record.expires_at - Time.current).to_i,
              user: {
                id: @user.id,
                name: @user.name,
                role: @user.role,
                email: @user.email,
                phone: @user.phone
              }
            }, status: :ok
          else
            render json: { error: 'Invalid credentials' }, status: :unauthorized
          end
        end
      end

      # POST /api/v1/customer_login
      def customer_login
        @customer = Customer.find_by(phone_number: params[:phone])

        if @customer&.authenticate(params[:password]) && @customer.is_active?
          token = JsonWebToken.encode(customer_id: @customer.id)
          refresh_token, refresh_record = issue_refresh_token(@customer)
          render json: {
            token: token,
            refresh_token: refresh_token,
            token_expires_in: 24.hours.to_i,
            refresh_token_expires_in: (refresh_record.expires_at - Time.current).to_i,
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

      # POST /api/v1/signup
      def signup
        if params[:role] == "customer"
          @user1 = User.first
          @user = Customer.new(customer_params.merge(user: @user1))
        else
          @user = User.new(user_params)
        end
        if @user.save
          # If role is customer, create customer record
          if params[:role] == "customer"
              @customer = @user
              token = JsonWebToken.encode(customer_id: @user.id)
              refresh_token, refresh_record = issue_refresh_token(@customer)

              render json: {
                token: token,
                refresh_token: refresh_token,
                token_expires_in: 24.hours.to_i,
                refresh_token_expires_in: (refresh_record.expires_at - Time.current).to_i,
                customer: {
                  id: @customer.id,
                  name: @customer.name,
                  address: @customer.address,
                  phone_number: @customer.phone_number,
                  email: @customer.email,
                  latitude: @customer.latitude,
                  longitude: @customer.longitude
                }
              }, status: :created
          else
            # For admin and delivery_person roles
            token = JsonWebToken.encode(user_id: @user.id)
            refresh_token, refresh_record = issue_refresh_token(@user)
            render json: {
              token: token,
              refresh_token: refresh_token,
              token_expires_in: 24.hours.to_i,
              refresh_token_expires_in: (refresh_record.expires_at - Time.current).to_i,
              user: {
                id: @user.id,
                name: @user.name,
                role: @user.role,
                email: @user.email,
                phone: @user.phone
              }
            }, status: :created
          end
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/customer_signup
      def customer_signup
        @customer = Customer.new(customer_signup_params)

        if @customer.save
          token = JsonWebToken.encode(customer_id: @customer.id)
          refresh_token, refresh_record = issue_refresh_token(@customer)
          render json: {
            token: token,
            refresh_token: refresh_token,
            token_expires_in: 24.hours.to_i,
            refresh_token_expires_in: (refresh_record.expires_at - Time.current).to_i,
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
      # Re-issue a new access token for the currently authenticated principal
      def regenerate_token
        entity = current_entity_from_token
        return render json: { error: 'Authentication required' }, status: :unauthorized if entity.nil?

        token = if entity.is_a?(Customer)
          JsonWebToken.encode(customer_id: entity.id)
        else
          JsonWebToken.encode(user_id: entity.id)
        end

        render json: { token: token, message: 'Token regenerated successfully' }, status: :ok
      end

      # POST /api/v1/refresh_token
      # Exchange a valid refresh token for a new access token and a rotated refresh token
      def refresh_token
        raw_refresh = params[:refresh_token]
        return render json: { error: 'refresh_token is required' }, status: :bad_request if raw_refresh.blank?

        token_record = RefreshToken.find_valid_by_raw(raw_refresh)
        return render json: { error: 'Invalid or expired refresh token' }, status: :unauthorized if token_record.nil?

        entity = token_record.entity

        # Rotate refresh token
        new_raw, new_record = issue_refresh_token(entity)
        token_record.revoke!(replaced_by_token_hash: new_record.token_hash)

        # Issue access token
        access_token = if entity.is_a?(Customer)
          JsonWebToken.encode(customer_id: entity.id)
        else
          JsonWebToken.encode(user_id: entity.id)
        end

        payload = {
          token: access_token,
          refresh_token: new_raw,
          token_expires_in: 24.hours.to_i,
          refresh_token_expires_in: (new_record.expires_at - Time.current).to_i
        }

        if entity.is_a?(Customer)
          payload[:customer] = {
            id: entity.id,
            name: entity.name,
            address: entity.address,
            phone_number: entity.phone_number,
            email: entity.email,
            preferred_language: entity.preferred_language,
            delivery_time_preference: entity.delivery_time_preference,
            notification_method: entity.notification_method
          }
        else
          payload[:user] = {
            id: entity.id,
            name: entity.name,
            role: entity.role,
            email: entity.email,
            phone: entity.phone
          }
        end

        render json: payload, status: :ok
      end

      private

      def issue_refresh_token(entity)
        user_agent = request.user_agent
        ip_address = request.remote_ip
        RefreshToken.issue_for(entity, user_agent: user_agent, ip_address: ip_address)
      end

      def current_entity_from_token
        # BaseController#authenticate_request sets @current_user to User or Customer
        current_entity
      end

      def user_params
        params.permit(:name, :email, :phone, :password, :role)
      end

      def customer_params
        params.permit(:name,:password, :address, :phone_number, :email, :latitude, :longitude,
                     :preferred_language, :delivery_time_preference, :notification_method,
                     :address_type, :address_landmark, :alt_phone_number)
      end

      def customer_signup_params
        params.permit(:name, :email, :phone_number, :password, :password_confirmation, :address,
                     :latitude, :longitude, :preferred_language, :delivery_time_preference,
                     :notification_method, :address_type, :address_landmark, :alt_phone_number)
      end
    end
  end
end